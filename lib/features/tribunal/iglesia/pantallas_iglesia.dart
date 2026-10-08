import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_router.dart';
import '../api_tribunal.dart';
import '../widgets_tribunal.dart';

/// Datos y resumen de miembros de la iglesia asignada al IglesiaAdmin.
class PantallaMiIglesia extends StatelessWidget {
  const PantallaMiIglesia({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<ApiTribunal>();
    return Scaffold(
      appBar: AppBar(title: const Text('Mi iglesia')),
      body: VistaConsulta<IglesiaResumen>(
        cargar: api.iglesia,
        construir: (context, iglesia) => ContenidoConsulta(
          children: [
            Seccion(
              titulo: iglesia.nombre,
              children: [
                Dato('Comunidad', iglesia.comunidad),
                Dato('Ubicación', iglesia.lugar),
              ],
            ),
            Seccion(
              titulo: 'Miembros',
              children: [
                Indicadores({
                  'Miembros activos': formatoNumero(iglesia.totalMiembros),
                  'Habilitados para participar': formatoNumero(iglesia.habilitados),
                  'No habilitados': formatoNumero(iglesia.noHabilitados),
                  'Información completa': formatoNumero(iglesia.informacionCompleta),
                  'Pendientes de revisión': formatoNumero(iglesia.pendientesRevision),
                  'También en otra iglesia': formatoNumero(iglesia.enOtraIglesia),
                }),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => context.go(Rutas.miembrosIglesia),
                  icon: const Icon(Icons.people_outline),
                  label: const Text('Ver miembros'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Miembros de la iglesia, por páginas, con búsqueda y filtro de habilitación.
class PantallaMiembrosIglesia extends StatefulWidget {
  const PantallaMiembrosIglesia({super.key});

  @override
  State<PantallaMiembrosIglesia> createState() => _PantallaMiembrosIglesiaState();
}

class _PantallaMiembrosIglesiaState extends State<PantallaMiembrosIglesia> {
  static const int _tamano = 30;

  final _desplazamiento = ScrollController();
  final List<Miembro> _miembros = [];
  Timer? _espera;
  String _busqueda = '';
  bool? _habilitado;
  int _total = 0;
  int _pagina = 0;
  bool _cargando = false;
  String? _error;
  int _consulta = 0;

  @override
  void initState() {
    super.initState();
    _desplazamiento.addListener(() {
      if (_desplazamiento.position.extentAfter < 300) _cargarMas();
    });
    _reiniciar();
  }

  @override
  void dispose() {
    _espera?.cancel();
    _desplazamiento.dispose();
    super.dispose();
  }

  void _reiniciar() {
    _consulta++;
    setState(() {
      _miembros.clear();
      _pagina = 0;
      _total = 0;
      _error = null;
      _cargando = false;
    });
    _cargarMas(forzar: true);
  }

  Future<void> _cargarMas({bool forzar = false}) async {
    if (_cargando || (!forzar && _miembros.length >= _total)) return;
    final consulta = _consulta;
    setState(() => _cargando = true);
    try {
      final pagina = await context
          .read<ApiTribunal>()
          .miembros(busqueda: _busqueda, habilitado: _habilitado, pagina: _pagina, tamano: _tamano);
      if (!mounted || consulta != _consulta) return;
      setState(() {
        _miembros.addAll(pagina.elementos);
        _total = pagina.total;
        _pagina++;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted || consulta != _consulta) return;
      setState(() {
        _error = mensajeDeError(e);
        _cargando = false;
      });
    }
  }

  void _buscar(String texto) {
    _espera?.cancel();
    _espera = Timer(const Duration(milliseconds: 400), () {
      _busqueda = texto.trim();
      _reiniciar();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Miembros')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              decoration: const InputDecoration(labelText: 'Buscar por nombre', prefixIcon: Icon(Icons.search)),
              onChanged: _buscar,
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (final (valor, texto) in const [(null, 'Todos'), (true, 'Habilitados'), (false, 'No habilitados')])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(texto),
                      selected: _habilitado == valor,
                      onSelected: (_) {
                        _habilitado = valor;
                        _reiniciar();
                      },
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Align(alignment: Alignment.centerLeft, child: Text('${formatoNumero(_total)} miembros')),
          ),
          Expanded(child: _lista()),
        ],
      ),
    );
  }

  Widget _lista() {
    if (_error != null && _miembros.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _reiniciar, child: const Text('Reintentar')),
          ]),
        ),
      );
    }
    if (_miembros.isEmpty) {
      return Center(child: _cargando ? const CircularProgressIndicator() : const Text('No hay miembros para mostrar.'));
    }
    return ListView.separated(
      controller: _desplazamiento,
      itemCount: _miembros.length + (_miembros.length < _total ? 1 : 0),
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        if (i >= _miembros.length) {
          return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
        }
        final m = _miembros[i];
        return ListTile(
          title: Text(m.nombre),
          subtitle: Text(m.habilitado ? 'Habilitado para participar' : 'No habilitado'),
          trailing: m.revisado ? const Tooltip(message: 'Información revisada', child: Icon(Icons.verified_outlined)) : null,
        );
      },
    );
  }
}

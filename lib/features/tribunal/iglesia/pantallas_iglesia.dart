import 'dart:async';

import 'package:flutter/material.dart';
import '../../../shared/widgets/estructura_adaptativa.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_router.dart';
import '../api_tribunal.dart';
import '../widgets_tribunal.dart';
import 'pantalla_editar_miembro.dart';
import '../../../shared/widgets/estados_app.dart';
import '../../../shared/widgets/etiquetas.dart';

/// Datos y resumen de miembros de la iglesia asignada al IglesiaAdmin.
class PantallaMiIglesia extends StatelessWidget {
  const PantallaMiIglesia({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<ApiTribunal>();
    return EstructuraAdaptativa(
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
                  'Total de miembros': formatoNumero(iglesia.totalMiembros),
                  'Habilitados / Total':
                      '${formatoNumero(iglesia.habilitados)} / ${formatoNumero(iglesia.totalMiembros)}',
                  'No habilitados': formatoNumero(iglesia.noHabilitados),
                  'Información completa': formatoNumero(
                    iglesia.informacionCompleta,
                  ),
                  'Pendientes de revisión': formatoNumero(
                    iglesia.pendientesRevision,
                  ),
                  'También en otra iglesia': formatoNumero(
                    iglesia.enOtraIglesia,
                  ),
                }),
                const SizedBox(height: 16),
                if (iglesia.pendientesRevision > 0) ...[
                  FilledButton.icon(
                    onPressed: () =>
                        context.go('${Rutas.miembrosIglesia}?pendientes=1'),
                    icon: const Icon(Icons.pending_actions_outlined),
                    label: Text(
                      'Ver pendientes de revisión (${formatoNumero(iglesia.pendientesRevision)})',
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
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
  const PantallaMiembrosIglesia({super.key, this.soloPendientes = false});

  /// Abre la lista filtrada en los miembros pendientes de revisión.
  final bool soloPendientes;

  @override
  State<PantallaMiembrosIglesia> createState() =>
      _PantallaMiembrosIglesiaState();
}

class _PantallaMiembrosIglesiaState extends State<PantallaMiembrosIglesia> {
  static const int _tamano = 30;

  final _desplazamiento = ScrollController();
  final List<Miembro> _miembros = [];
  Timer? _espera;
  String _busqueda = '';
  bool? _habilitado;

  /// Solo los pendientes de revisión (en TEC: `revisado = false`).
  late bool _soloPendientes = widget.soloPendientes;
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
    _consultarCronograma();
  }

  /// Si el cronograma permite editar el padrón (lo informa TEC); null mientras se consulta.
  /// Solo habilita «Agregar persona», como el botón «Nuevo» de la web; TEC vuelve a validar.
  bool? _permiteEdicion;

  Future<void> _consultarCronograma() async {
    try {
      final iglesia = await context.read<ApiTribunal>().iglesia();
      if (mounted) setState(() => _permiteEdicion = iglesia.permiteEdicion);
    } catch (_) {
      // Sin el dato, el botón queda disponible y TEC decide al guardar.
      if (mounted) setState(() => _permiteEdicion = true);
    }
  }

  /// Única entrada a la edición: abre «Datos de la persona» (que consulta el detalle
  /// actualizado a TEC). Si se guardó, actualiza solo esa fila; si se dio de baja, la
  /// quita. No recarga la lista.
  Future<void> _editar(Miembro miembro) async {
    final resultado = await context.push<ResultadoMiembro>(
      Rutas.editarMiembro(miembro.id),
    );
    if (resultado == null || !mounted) return;
    switch (resultado) {
      case MiembroGuardado(:final detalle):
        final i = _miembros.indexWhere((m) => m.id == detalle.id);
        if (i < 0) return;
        setState(() {
          _miembros[i] = Miembro(
            id: detalle.id,
            nombre: detalle.nombre,
            sexo: detalle.sexo,
            habilitado: detalle.habilitado,
            revisado: detalle.revisado,
          );
        });
      case MiembroDadoDeBaja(:final id):
        setState(() {
          final antes = _miembros.length;
          _miembros.removeWhere((m) => m.id == id);
          _total -= antes - _miembros.length;
        });
    }
  }

  /// Agrega una persona y vuelve a consultar la lista para mostrarla en su orden.
  Future<void> _agregar() async {
    final resultado = await context.push<ResultadoMiembro>(Rutas.nuevoMiembro);
    if (resultado is MiembroGuardado && mounted) _reiniciar();
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
    if (_cargando ||
        (!forzar && (_error != null || _miembros.length >= _total))) {
      return;
    }
    final consulta = _consulta;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final pagina = await context.read<ApiTribunal>().miembros(
        busqueda: _busqueda,
        habilitado: _habilitado,
        revisado: _soloPendientes ? false : null,
        pagina: _pagina,
        tamano: _tamano,
      );
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
    final tema = Theme.of(context);
    return EstructuraAdaptativa(
      appBar: AppBar(title: const Text('Miembros')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Buscar por nombre',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _buscar,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final (valor, texto) in const [
                  (null, 'Todos'),
                  (true, 'Habilitados'),
                  (false, 'No habilitados'),
                ])
                  ChoiceChip(
                    label: Text(texto),
                    selected: _habilitado == valor,
                    onSelected: (_) {
                      _habilitado = valor;
                      _reiniciar();
                    },
                  ),
                // Se combina con el filtro de habilitación (p. ej. no habilitados sin revisar).
                FilterChip(
                  label: const Text('Pendientes de revisión'),
                  selected: _soloPendientes,
                  onSelected: (valor) {
                    _soloPendientes = valor;
                    _reiniciar();
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  _soloPendientes
                      ? '${formatoNumero(_total)} pendientes de revisión'
                      : '${formatoNumero(_total)} miembros',
                  style: tema.textTheme.bodySmall,
                ),
                Tooltip(
                  message: _permiteEdicion == false
                      ? 'El cronograma no permite editar el padrón.'
                      : 'Registrar una persona en la iglesia',
                  child: FilledButton.tonalIcon(
                    onPressed: _permiteEdicion == true ? _agregar : null,
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    label: const Text('Agregar persona'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _lista()),
        ],
      ),
    );
  }

  Widget _lista() {
    if (_error != null && _miembros.isEmpty) {
      return EstadoError(mensaje: _error!, reintentar: _reiniciar);
    }
    if (_miembros.isEmpty) {
      return _cargando
          ? const EstadoCarga()
          : const EstadoVacio(mensaje: 'No hay miembros para mostrar.');
    }
    return ListView.separated(
      controller: _desplazamiento,
      itemCount: _miembros.length + (_miembros.length < _total ? 1 : 0),
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        if (i >= _miembros.length) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: _error != null
                ? EstadoError(
                    mensaje: _error!,
                    reintentar: () => _cargarMas(forzar: true),
                  )
                : const EstadoCarga(),
          );
        }
        final m = _miembros[i];
        return _FilaMiembro(miembro: m, alEditar: () => _editar(m));
      },
    );
  }
}

/// Fila de consulta de un miembro: nombre, sexo, estado del padrón, revisión pendiente y
/// el lápiz como única acción. No contiene controles editables.
class _FilaMiembro extends StatelessWidget {
  const _FilaMiembro({required this.miembro, required this.alEditar});

  final Miembro miembro;
  final VoidCallback alEditar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  miembro.nombre,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    DatoSexo(miembro.sexo),
                    EtiquetaPadron(habilitado: miembro.habilitado),
                    if (!miembro.revisado) const EtiquetaPendienteRevision(),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Editar datos de ${miembro.nombre}',
            onPressed: alEditar,
          ),
        ],
      ),
    );
  }
}

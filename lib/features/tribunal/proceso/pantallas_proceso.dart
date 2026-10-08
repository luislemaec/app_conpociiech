import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_router.dart';
import '../api_tribunal.dart';
import '../widgets_tribunal.dart';

/// Resumen del proceso activo para Tribunal y Administrador.
class PantallaProceso extends StatelessWidget {
  const PantallaProceso({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<ApiTribunal>();
    return Scaffold(
      appBar: AppBar(title: const Text('Proceso electoral')),
      body: VistaConsulta<ResumenProceso>(
        cargar: api.resumenProceso,
        construir: (context, r) => ContenidoConsulta(
          children: [
            Seccion(
              titulo: r.proceso.nombre,
              children: [
                Dato('Fase vigente', r.proceso.faseVigente),
                const SizedBox(height: 8),
                Indicadores({
                  'Iglesias': formatoNumero(r.iglesias),
                  'Recintos': formatoNumero(r.recintos),
                  'Mesas': formatoNumero(r.mesas),
                  'Electores': formatoNumero(r.electores),
                  'Juntas completas': '${formatoNumero(r.mesasConJuntaCompleta)} / ${formatoNumero(r.mesas)}',
                  'Mesas cerradas': '${formatoNumero(r.mesasCerradas)} (${r.porcentajeEscrutinio} %)',
                }),
              ],
            ),
            if (r.mesasPorEstado.isNotEmpty)
              Seccion(
                titulo: 'Mesas por estado',
                children: [
                  for (final e in r.mesasPorEstado.entries) Dato(EstadoMesa.etiqueta(e.key), formatoNumero(e.value)),
                ],
              ),
            FilledButton.icon(
              onPressed: () => context.go(Rutas.avanceMesas),
              icon: const Icon(Icons.table_rows_outlined),
              label: const Text('Avance de mesas'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => context.go(Rutas.resultados),
              icon: const Icon(Icons.bar_chart),
              label: const Text('Resultados consolidados'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Estado de cada mesa con filtros por cantón, recinto y estado (filtrado en el dispositivo).
class PantallaAvanceMesas extends StatefulWidget {
  const PantallaAvanceMesas({super.key});

  @override
  State<PantallaAvanceMesas> createState() => _PantallaAvanceMesasState();
}

class _PantallaAvanceMesasState extends State<PantallaAvanceMesas> {
  String? _canton;
  String? _recinto;
  String? _estado;

  @override
  Widget build(BuildContext context) {
    final api = context.read<ApiTribunal>();
    return Scaffold(
      appBar: AppBar(title: const Text('Avance de mesas')),
      body: VistaConsulta<List<AvanceMesa>>(
        cargar: api.avanceMesas,
        construir: (context, mesas) {
          final cantones = {for (final m in mesas) ?m.ubicacion.canton}.toList()..sort();
          final recintos = {
            for (final m in mesas)
              if (_canton == null || m.ubicacion.canton == _canton) ?m.ubicacion.recinto,
          }.toList()
            ..sort();
          final estados = {for (final m in mesas) m.estado}.toList()..sort();
          final visibles = mesas
              .where((m) =>
                  (_canton == null || m.ubicacion.canton == _canton) &&
                  (_recinto == null || m.ubicacion.recinto == _recinto) &&
                  (_estado == null || m.estado == _estado))
              .toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  children: [
                    _Filtro(
                      etiqueta: 'Cantón',
                      valor: _canton,
                      opciones: {for (final c in cantones) c: c},
                      cambiar: (v) => setState(() {
                        _canton = v;
                        _recinto = null;
                      }),
                    ),
                    const SizedBox(height: 8),
                    _Filtro(
                      etiqueta: 'Recinto',
                      valor: recintos.contains(_recinto) ? _recinto : null,
                      opciones: {for (final r in recintos) r: r},
                      cambiar: (v) => setState(() => _recinto = v),
                    ),
                    const SizedBox(height: 8),
                    _Filtro(
                      etiqueta: 'Estado',
                      valor: _estado,
                      opciones: {for (final e in estados) e: EstadoMesa.etiqueta(e)},
                      cambiar: (v) => setState(() => _estado = v),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('${formatoNumero(visibles.length)} de ${formatoNumero(mesas.length)} mesas'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: visibles.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final m = visibles[i];
                    return ListTile(
                      title: Text(m.ubicacion.mesa),
                      subtitle: Text([
                        m.ubicacion.recinto,
                        m.ubicacion.lugar,
                        m.juntaRegistrada ? 'Junta completa' : 'Junta incompleta',
                      ].whereType<String>().where((t) => t.isNotEmpty).join(' · ')),
                      trailing: EtiquetaEstado(m.estado),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Filtro extends StatelessWidget {
  const _Filtro({required this.etiqueta, required this.valor, required this.opciones, required this.cambiar});

  final String etiqueta;
  final String? valor;
  final Map<String, String> opciones;
  final ValueChanged<String?> cambiar;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String?>(
      key: ValueKey('$etiqueta-$valor-${opciones.length}'),
      initialValue: valor,
      isExpanded: true,
      decoration: InputDecoration(labelText: etiqueta, isDense: true),
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('Todos')),
        for (final o in opciones.entries)
          DropdownMenuItem<String?>(value: o.key, child: Text(o.value, overflow: TextOverflow.ellipsis)),
      ],
      onChanged: cambiar,
    );
  }
}

/// Resultados consolidados de las mesas cerradas.
class PantallaResultados extends StatelessWidget {
  const PantallaResultados({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<ApiTribunal>();
    return Scaffold(
      appBar: AppBar(title: const Text('Resultados')),
      body: VistaConsulta<ResultadosProceso>(
        cargar: api.resultadosProceso,
        construir: (context, r) {
          final tema = Theme.of(context);
          return ContenidoConsulta(
            children: [
              Seccion(
                titulo: r.proceso,
                children: [
                  Indicadores({
                    'Mesas cerradas': '${formatoNumero(r.mesasCerradas)} / ${formatoNumero(r.mesas)}',
                    'Avance': '${r.porcentajeMesasCerradas} %',
                    'Votos registrados': formatoNumero(r.votosRegistrados),
                    'Blancos': formatoNumero(r.votosBlancos),
                    'Nulos': formatoNumero(r.votosNulos),
                  }),
                  const SizedBox(height: 8),
                  Text('Actualizado: ${formatoFecha(r.actualizado)}', style: tema.textTheme.bodySmall),
                ],
              ),
              Seccion(
                titulo: 'Votos por lista',
                children: [
                  if (r.categorias.isEmpty) const Text('Aún no hay mesas cerradas.'),
                  for (final c in r.categorias) ...[
                    Row(
                      children: [
                        Expanded(child: Text(c.nombre)),
                        Text('${formatoNumero(c.votos)} · ${c.porcentaje.toStringAsFixed(2)} %'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(value: (c.porcentaje / 100).clamp(0, 1)),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

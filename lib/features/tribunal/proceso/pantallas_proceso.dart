import 'package:flutter/material.dart';
import '../../../shared/widgets/estructura_adaptativa.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_router.dart';
import '../api_tribunal.dart';
import '../widgets_tribunal.dart';
import '../../../shared/widgets/estados_app.dart';

/// Resumen del proceso activo para Tribunal y Administrador.
class PantallaProceso extends StatelessWidget {
  const PantallaProceso({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<ApiTribunal>();
    return EstructuraAdaptativa(
      appBar: AppBar(title: const Text('Proceso electoral')),
      body: VistaConsulta<ResumenProceso>(
        cargar: api.resumenProceso,
        construir: (context, r) => ContenidoConsulta(
          children: [
            if (r.alertas.isNotEmpty) _Alertas(r.alertas),
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
                  'Juntas completas':
                      '${formatoNumero(r.mesasConJuntaCompleta)} / ${formatoNumero(r.mesas)}',
                  'Mesas cerradas':
                      '${formatoNumero(r.mesasCerradas)} (${r.porcentajeEscrutinio} %)',
                }),
              ],
            ),
            if (r.mesasPorEstado.isNotEmpty)
              Seccion(
                titulo: 'Mesas por estado',
                children: [
                  for (final e in r.mesasPorEstado.entries)
                    Dato(EstadoMesa.etiqueta(e.key), formatoNumero(e.value)),
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

/// Pendientes del proceso (las alertas del dashboard web). Tocar una abre el avance de mesas.
class _Alertas extends StatelessWidget {
  const _Alertas(this.alertas);

  final List<AlertaProceso> alertas;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Seccion(
      titulo: 'Alertas',
      children: [
        for (final a in alertas)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              a.critica ? Icons.error_outline : Icons.warning_amber_outlined,
              color: a.critica ? esquema.error : esquema.tertiary,
              semanticLabel: a.critica ? 'Crítica' : 'Advertencia',
            ),
            title: Text(a.texto),
            trailing: a.cantidad > 0
                ? Text(
                    formatoNumero(a.cantidad),
                    style: Theme.of(context).textTheme.titleMedium,
                  )
                : null,
            onTap: () => context.go(Rutas.avanceMesas),
          ),
      ],
    );
  }
}

/// Fase de cada mesa (calculada por TEC, igual que la columna Situación de actaE) con filtros
/// por cantón, recinto y fase. Todo se filtra y cuenta en el dispositivo sobre una sola
/// consulta; la App no deduce la fase de otros datos.
class PantallaAvanceMesas extends StatefulWidget {
  const PantallaAvanceMesas({super.key});

  @override
  State<PantallaAvanceMesas> createState() => _PantallaAvanceMesasState();
}

class _PantallaAvanceMesasState extends State<PantallaAvanceMesas> {
  String? _canton;
  String? _recinto;

  /// Código de fase de TEC; null = todas. Filtro exacto, como en actaE.
  String? _fase;

  @override
  Widget build(BuildContext context) {
    final api = context.read<ApiTribunal>();
    return EstructuraAdaptativa(
      appBar: AppBar(title: const Text('Avance de mesas')),
      body: VistaConsulta<List<AvanceMesa>>(
        cargar: api.avanceMesas,
        construir: (context, mesas) {
          final cantones = {for (final m in mesas) ?m.ubicacion.canton}.toList()
            ..sort();
          final recintos = {
            for (final m in mesas)
              if (_canton == null || m.ubicacion.canton == _canton)
                ?m.ubicacion.recinto,
          }.toList()..sort();
          // Mesas del cantón y recinto elegidos: base de los contadores por fase.
          final enAlcance = mesas
              .where(
                (m) =>
                    (_canton == null || m.ubicacion.canton == _canton) &&
                    (_recinto == null || m.ubicacion.recinto == _recinto),
              )
              .toList();
          final porFase = <String, int>{};
          for (final m in enAlcance) {
            if (m.fase case final f?) {
              porFase[f.fase] = (porFase[f.fase] ?? 0) + 1;
            }
          }
          // Textos de TEC cuando llegan; el catálogo solo completa fases sin mesas.
          final etiquetas = {
            ...FaseEscrutinio.catalogo,
            for (final m in mesas)
              if (m.fase case final f?) f.fase: f.etiqueta,
          };
          final visibles = _fase == null
              ? enAlcance
              : enAlcance.where((m) => m.fase?.fase == _fase).toList();
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
                    const SizedBox(height: 12),
                    _FiltroFase(
                      seleccion: _fase,
                      total: enAlcance.length,
                      etiquetas: etiquetas,
                      cantidades: porFase,
                      cambiar: (v) => setState(() => _fase = v),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${formatoNumero(visibles.length)} de ${formatoNumero(mesas.length)} mesas',
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: visibles.isEmpty
                    ? const EstadoVacio(
                        mensaje:
                            'No hay resultados para los filtros seleccionados.',
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: visibles.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final m = visibles[i];
                          return ListTile(
                            title: Text(m.ubicacion.mesa),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  [
                                        m.ubicacion.recinto,
                                        m.ubicacion.lugar,
                                        m.juntaRegistrada
                                            ? 'Junta completa'
                                            : 'Junta incompleta',
                                      ]
                                      .whereType<String>()
                                      .where((t) => t.isNotEmpty)
                                      .join(' · '),
                                ),
                                if (m.fase != null) ...[
                                  const SizedBox(height: 4),
                                  DetalleFase(m.fase!),
                                ],
                              ],
                            ),
                            // Fase calculada por TEC (misma que la columna Situación de actaE).
                            trailing: m.fase == null
                                ? null
                                : EtiquetaFase(m.fase!, compacta: true),
                            onTap: m.ubicacion.mesaId == null
                                ? null
                                : () => context.go(
                                    Rutas.detalleMesa(m.ubicacion.mesaId!),
                                  ),
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
  const _Filtro({
    required this.etiqueta,
    required this.valor,
    required this.opciones,
    required this.cambiar,
  });

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
          DropdownMenuItem<String?>(
            value: o.key,
            child: Text(o.value, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: cambiar,
    );
  }
}

/// Filtro exacto por fase con el número de mesas de cada una (Todas + las cinco fases de
/// TEC en orden oficial). Los contadores salen de la misma lista que se muestra.
class _FiltroFase extends StatelessWidget {
  const _FiltroFase({
    required this.seleccion,
    required this.total,
    required this.etiquetas,
    required this.cantidades,
    required this.cambiar,
  });

  final String? seleccion;
  final int total;
  final Map<String, String> etiquetas;
  final Map<String, int> cantidades;
  final ValueChanged<String?> cambiar;

  @override
  Widget build(BuildContext context) {
    Widget opcion(String? codigo, String texto, int cantidad) => ChoiceChip(
      label: Text('$texto (${formatoNumero(cantidad)})'),
      avatar: codigo == null
          ? null
          : Icon(EtiquetaFase.icono(codigo), size: 18),
      showCheckmark: false,
      selected: seleccion == codigo,
      onSelected: (_) => cambiar(codigo),
    );
    return Semantics(
      container: true,
      label: 'Filtrar por fase',
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            opcion(null, 'Todas', total),
            for (final f in FaseEscrutinio.catalogo.keys)
              opcion(f, etiquetas[f]!, cantidades[f] ?? 0),
          ],
        ),
      ),
    );
  }
}

/// Resultados consolidados de las mesas cerradas.
class PantallaResultados extends StatelessWidget {
  const PantallaResultados({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<ApiTribunal>();
    return EstructuraAdaptativa(
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
                    'Mesas cerradas':
                        '${formatoNumero(r.mesasCerradas)} / ${formatoNumero(r.mesas)}',
                    'Avance': '${r.porcentajeMesasCerradas} %',
                    'Votos registrados': formatoNumero(r.votosRegistrados),
                    'Blancos': formatoNumero(r.votosBlancos),
                    'Nulos': formatoNumero(r.votosNulos),
                  }),
                  const SizedBox(height: 8),
                  Text(
                    'Actualizado: ${formatoFecha(r.actualizado)}',
                    style: tema.textTheme.bodySmall,
                  ),
                ],
              ),
              Seccion(
                titulo: 'Votos por lista',
                children: [
                  if (r.categorias.isEmpty)
                    const Text('Aún no hay mesas cerradas.'),
                  for (final c in r.categorias) ...[
                    Row(
                      children: [
                        Expanded(child: Text(c.nombre)),
                        Text(
                          '${formatoNumero(c.votos)} · ${c.porcentaje.toStringAsFixed(2)} %',
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: (c.porcentaje / 100).clamp(0, 1),
                    ),
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

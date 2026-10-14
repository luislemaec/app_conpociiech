import 'package:flutter/material.dart';

import '../../core/api/cliente_api.dart';
import '../../shared/widgets/estados_app.dart';
import '../../shared/tema/colores_semanticos.dart';
import '../../shared/widgets/etiquetas.dart';
import '../../shared/tema/diseno_app.dart';
import 'api_tribunal.dart';

/// Carga una consulta de TEC y muestra progreso, error con reintento o el contenido.
/// Deslizar hacia abajo vuelve a consultar. Si la sesión expiró, la guarda de rutas ya
/// lleva al inicio de sesión.
class VistaConsulta<T> extends StatefulWidget {
  const VistaConsulta({
    super.key,
    required this.cargar,
    required this.construir,
  });

  final Future<T> Function() cargar;
  final Widget Function(BuildContext context, T datos) construir;

  @override
  State<VistaConsulta<T>> createState() => _VistaConsultaState<T>();
}

class _VistaConsultaState<T> extends State<VistaConsulta<T>> {
  late Future<T> _futuro = widget.cargar();

  Future<void> _recargar() async {
    final futuro = widget.cargar();
    setState(() => _futuro = futuro);
    try {
      await futuro;
    } catch (_) {
      // El error se muestra en el FutureBuilder.
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _futuro,
      builder: (context, estado) {
        if (estado.connectionState != ConnectionState.done) {
          return const EstadoCarga();
        }
        if (estado.hasError) {
          return EstadoError(
            mensaje: mensajeDeError(estado.error),
            reintentar: _recargar,
          );
        }
        return RefreshIndicator(
          onRefresh: _recargar,
          child: widget.construir(context, estado.data as T),
        );
      },
    );
  }
}

String mensajeDeError(Object? error) => switch (error) {
  ErrorApi(:final mensaje) => mensaje,
  SinConexion() => SinConexion.mensaje,
  _ => 'No se pudo cargar la información. Inténtelo más tarde.',
};

/// Lista desplazable con márgenes y ancho máximo, apta para RefreshIndicator.
class ContenidoConsulta extends StatelessWidget {
  const ContenidoConsulta({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: DisenoApp.anchoContenido),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: DisenoApp.margen(MediaQuery.sizeOf(context).width),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: children,
        ),
      ),
    );
  }
}

/// Tarjeta con título y contenido.
class Seccion extends StatelessWidget {
  const Seccion({super.key, required this.titulo, required this.children});

  final String titulo;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(titulo, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Fila «etiqueta: valor».
class Dato extends StatelessWidget {
  const Dato(this.etiqueta, this.valor, {super.key});

  final String etiqueta;
  final String? valor;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: MediaQuery.sizeOf(context).width < 600 ? 104 : 160,
            child: Text(etiqueta, style: tema.bodySmall),
          ),
          Expanded(
            child: Text(
              valor == null || valor!.isEmpty ? '—' : valor!,
              style: tema.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

/// Indicadores numéricos en cuadrícula.
class Indicadores extends StatelessWidget {
  const Indicadores(this.valores, {super.key});

  final Map<String, String> valores;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return LayoutBuilder(
      builder: (context, limites) {
        final columnas = limites.maxWidth < 400
            ? 2
            : limites.maxWidth < 700
            ? 3
            : 4;
        final ancho = (limites.maxWidth - (columnas - 1) * 12) / columnas;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final v in valores.entries)
              SizedBox(
                width: ancho,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: tema.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        v.value,
                        style: tema.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(v.key, style: tema.textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Etiqueta del estado de una mesa.
class EtiquetaEstado extends StatelessWidget {
  const EtiquetaEstado(this.estado, {super.key});

  final String estado;

  /// Misma severidad que el dashboard de TEC WEB (DashboardController.severidadEstado).
  static TonoSemantico tono(String estado) => switch (estado) {
    'CERRADO' => TonoSemantico.exito,
    'OBSERVADO' || 'ANULADO' => TonoSemantico.peligro,
    'PENDIENTE' => TonoSemantico.neutro,
    _ => TonoSemantico.advertencia,
  };

  @override
  Widget build(BuildContext context) =>
      EtiquetaSemantica(texto: EstadoMesa.etiqueta(estado), tono: tono(estado));
}

/// Fase del escrutinio tal como la calcula TEC. Punto único de la presentación de una fase:
/// texto (de TEC), ícono por fase y tono según la severidad de TEC WEB (la tabla de actaE
/// colorea por situación, no por fase). El color nunca va solo: siempre hay texto e ícono.
///
/// `compacta` muestra solo «3. Acta física» (para el extremo de una fila, junto a
/// [DetalleFase]); la forma completa agrega la situación y, debajo, la incidencia.
class EtiquetaFase extends StatelessWidget {
  const EtiquetaFase(this.fase, {super.key, this.compacta = false});

  final FaseEscrutinio fase;
  final bool compacta;

  static TonoSemantico tono(String severidad) => switch (severidad) {
    'success' => TonoSemantico.exito,
    'warning' => TonoSemantico.advertencia,
    'danger' => TonoSemantico.peligro,
    _ => TonoSemantico.informacion,
  };

  static IconData icono(String fase, {bool oficial = false}) => switch (fase) {
    'APERTURA' => Icons.lock_open_outlined,
    'CONTEO' => Icons.how_to_vote_outlined,
    'ACTA_FISICA' => Icons.document_scanner_outlined,
    'CIERRE' => Icons.lock_outline,
    _ => oficial ? Icons.verified_outlined : Icons.fact_check_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final etiqueta = EtiquetaSemantica(
      texto: compacta ? fase.titulo : fase.texto,
      tono: tono(fase.severidad),
      icono: icono(fase.fase, oficial: fase.oficial),
    );
    if (compacta || fase.incidenciaEtiqueta == null) return etiqueta;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        etiqueta,
        const SizedBox(height: DisenoApp.xs),
        _Incidencia(fase),
      ],
    );
  }
}

/// Situación dentro de la fase («Pendiente de carga») y, si existe, la incidencia
/// («Escrutinio reabierto»), como debajo de la etiqueta en la columna Situación de actaE.
class DetalleFase extends StatelessWidget {
  const DetalleFase(this.fase, {super.key});

  final FaseEscrutinio fase;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(fase.situacion, style: Theme.of(context).textTheme.bodySmall),
      if (fase.incidenciaEtiqueta != null) ...[
        const SizedBox(height: DisenoApp.xs),
        _Incidencia(fase),
      ],
    ],
  );
}

class _Incidencia extends StatelessWidget {
  const _Incidencia(this.fase);

  final FaseEscrutinio fase;

  @override
  Widget build(BuildContext context) {
    final color = context.semanticos
        .de(EtiquetaFase.tono(fase.severidad))
        .primerPlano;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: Icon(Icons.error_outline, size: 16, color: color),
        ),
        const SizedBox(width: DisenoApp.xs),
        Flexible(
          child: Text(
            fase.incidenciaEtiqueta!,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

String formatoNumero(int n) {
  final s = n.abs().toString();
  final partes = <String>[];
  for (var i = s.length; i > 0; i -= 3) {
    partes.insert(0, s.substring(i - 3 < 0 ? 0 : i - 3, i));
  }
  return '${n < 0 ? '-' : ''}${partes.join('.')}';
}

String formatoFecha(DateTime? f) {
  if (f == null) return '—';
  String d(int v) => v.toString().padLeft(2, '0');
  return '${d(f.day)}/${d(f.month)}/${f.year} ${d(f.hour)}:${d(f.minute)}';
}

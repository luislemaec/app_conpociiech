import 'package:flutter/material.dart';

import '../../core/api/cliente_api.dart';
import 'api_tribunal.dart';

/// Carga una consulta de TEC y muestra progreso, error con reintento o el contenido.
/// Deslizar hacia abajo vuelve a consultar. Si la sesión expiró, la guarda de rutas ya
/// lleva al inicio de sesión.
class VistaConsulta<T> extends StatefulWidget {
  const VistaConsulta({super.key, required this.cargar, required this.construir});

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
          return const Center(child: CircularProgressIndicator());
        }
        if (estado.hasError) {
          return _Error(mensaje: mensajeDeError(estado.error), reintentar: _recargar);
        }
        return RefreshIndicator(onRefresh: _recargar, child: widget.construir(context, estado.data as T));
      },
    );
  }
}

String mensajeDeError(Object? error) => switch (error) {
      ErrorApi(:final mensaje) => mensaje,
      SinConexion() => SinConexion.mensaje,
      _ => 'No se pudo cargar la información. Inténtelo más tarde.',
    };

class _Error extends StatelessWidget {
  const _Error({required this.mensaje, required this.reintentar});

  final String mensaje;
  final VoidCallback reintentar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline, size: 40, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(mensaje, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton.icon(onPressed: reintentar, icon: const Icon(Icons.refresh), label: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}

/// Lista desplazable con márgenes y ancho máximo, apta para RefreshIndicator.
class ContenidoConsulta extends StatelessWidget {
  const ContenidoConsulta({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
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
          SizedBox(width: 120, child: Text(etiqueta, style: tema.bodySmall)),
          Expanded(child: Text(valor == null || valor!.isEmpty ? '—' : valor!, style: tema.bodyMedium)),
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
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final v in valores.entries)
          SizedBox(
            width: 140,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: tema.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(v.value, style: tema.textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(v.key, style: tema.textTheme.bodySmall),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Etiqueta del estado de una mesa.
class EtiquetaEstado extends StatelessWidget {
  const EtiquetaEstado(this.estado, {super.key});

  final String estado;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final (fondo, texto) = switch (estado) {
      'CERRADO' => (esquema.primaryContainer, esquema.onPrimaryContainer),
      'OBSERVADO' || 'ANULADO' => (esquema.errorContainer, esquema.onErrorContainer),
      'PENDIENTE' => (esquema.surfaceContainerHighest, esquema.onSurfaceVariant),
      _ => (esquema.secondaryContainer, esquema.onSecondaryContainer),
    };
    return DecoratedBox(
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(EstadoMesa.etiqueta(estado), style: Theme.of(context).textTheme.labelMedium?.copyWith(color: texto)),
      ),
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

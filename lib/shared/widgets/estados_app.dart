import 'package:flutter/material.dart';

class EstadoVacio extends StatelessWidget {
  const EstadoVacio({
    super.key,
    required this.mensaje,
    this.icono = Icons.search_off,
  });
  final String mensaje;
  final IconData icono;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 40, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          Text(mensaje, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class EstadoCarga extends StatelessWidget {
  const EstadoCarga({super.key});
  @override
  Widget build(BuildContext context) => Center(
    child: Semantics(
      label: 'Cargando información',
      liveRegion: true,
      child: CircularProgressIndicator.adaptive(),
    ),
  );
}

class EstadoError extends StatelessWidget {
  const EstadoError({
    super.key,
    required this.mensaje,
    required this.reintentar,
  });
  final String mensaje;
  final VoidCallback reintentar;
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: 40,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Semantics(
            liveRegion: true,
            child: Text(mensaje, textAlign: TextAlign.center),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: reintentar,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    ),
  );
}

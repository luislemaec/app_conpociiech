import 'package:flutter/material.dart';
import '../tema/diseno_app.dart';

class CabeceraApp extends StatelessWidget {
  const CabeceraApp({
    super.key,
    required this.titulo,
    required this.descripcion,
    required this.icono,
  });
  final String titulo, descripcion;
  final IconData icono;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: DisenoApp.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, size: 32, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: DisenoApp.md),
        Text(titulo, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: DisenoApp.sm),
        Text(descripcion, style: Theme.of(context).textTheme.bodyMedium),
      ],
    ),
  );
}

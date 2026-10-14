import 'package:flutter/material.dart';

import '../tema/colores_semanticos.dart';
import '../tema/diseno_app.dart';

/// Etiqueta compacta de estado: ícono + texto con el color de su significado
/// ([TonoSemantico]). El texto siempre acompaña al color (accesibilidad).
class EtiquetaSemantica extends StatelessWidget {
  const EtiquetaSemantica({
    super.key,
    required this.texto,
    required this.tono,
    this.icono,
  });

  final String texto;
  final TonoSemantico tono;
  final IconData? icono;

  @override
  Widget build(BuildContext context) {
    final par = context.semanticos.de(tono);
    final estilo = Theme.of(context).textTheme.labelMedium?.copyWith(color: par.primerPlano);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: par.fondo,
        borderRadius: BorderRadius.circular(DisenoApp.radioCampo),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icono != null) ...[
              ExcludeSemantics(child: Icon(icono, size: 16, color: par.primerPlano)),
              const SizedBox(width: DisenoApp.xs + 2),
            ],
            Flexible(child: Text(texto, style: estilo)),
          ],
        ),
      ),
    );
  }
}

/// Sexo almacenado en TEC (`M`, `F` o sin dato). Nunca se deduce de otros datos.
abstract final class Sexo {
  static String texto(String? valor) => switch (valor) {
        'M' => 'Masculino',
        'F' => 'Femenino',
        _ => 'Sin dato',
      };

  static IconData icono(String? valor) => switch (valor) {
        'M' => Icons.male,
        'F' => Icons.female,
        _ => Icons.person_outline,
      };
}

/// Sexo en modo consulta: ícono + texto (el ícono complementa, no reemplaza).
class DatoSexo extends StatelessWidget {
  const DatoSexo(this.valor, {super.key});

  final String? valor;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final color = tema.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(child: Icon(Sexo.icono(valor), size: 18, color: color)),
        const SizedBox(width: DisenoApp.xs),
        Text(Sexo.texto(valor), style: tema.textTheme.bodySmall),
      ],
    );
  }
}

/// Estado del padrón con la semántica de TEC WEB (Personas): Habilitado → éxito,
/// No habilitado → neutro.
class EtiquetaPadron extends StatelessWidget {
  const EtiquetaPadron({super.key, required this.habilitado});

  final bool habilitado;

  @override
  Widget build(BuildContext context) => habilitado
      ? const EtiquetaSemantica(
          texto: 'Habilitado',
          tono: TonoSemantico.exito,
          icono: Icons.check_circle_outline,
        )
      : const EtiquetaSemantica(
          texto: 'No habilitado',
          tono: TonoSemantico.neutro,
          icono: Icons.block,
        );
}

/// «Pendiente de revisión» (TEC WEB: warning). Revisado no se muestra en listas.
class EtiquetaPendienteRevision extends StatelessWidget {
  const EtiquetaPendienteRevision({super.key});

  @override
  Widget build(BuildContext context) => const EtiquetaSemantica(
        texto: 'Pendiente de revisión',
        tono: TonoSemantico.advertencia,
        icono: Icons.schedule,
      );
}

/// Aviso en línea (información, advertencia o error) con el tono semántico.
class AvisoSemantico extends StatelessWidget {
  const AvisoSemantico(this.texto, {super.key, this.tono = TonoSemantico.informacion});

  final String texto;
  final TonoSemantico tono;

  @override
  Widget build(BuildContext context) {
    final par = context.semanticos.de(tono);
    final icono = switch (tono) {
      TonoSemantico.peligro => Icons.error_outline,
      TonoSemantico.advertencia => Icons.warning_amber_outlined,
      TonoSemantico.exito => Icons.check_circle_outline,
      _ => Icons.info_outline,
    };
    return Semantics(
      liveRegion: tono == TonoSemantico.peligro,
      child: Container(
        padding: const EdgeInsets.all(DisenoApp.sm + DisenoApp.xs),
        decoration: BoxDecoration(
          color: par.fondo,
          borderRadius: BorderRadius.circular(DisenoApp.radioCampo),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(child: Icon(icono, size: 20, color: par.primerPlano)),
            const SizedBox(width: DisenoApp.sm),
            Expanded(
              child: Text(
                texto,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: par.primerPlano),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

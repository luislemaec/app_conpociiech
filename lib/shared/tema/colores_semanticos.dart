import 'package:flutter/material.dart';

import 'colores_tribunal.dart';

/// Significado de un estado; el color se elige por lo que comunica, no para decorar.
/// Misma semántica que las etiquetas de TEC WEB (p. ej. Personas: Habilitado → success,
/// No habilitado → secondary, Pendiente de revisión → warning, inconsistencia → danger).
enum TonoSemantico {
  /// Habilitado, correcto, activo, revisado.
  exito,

  /// Información, en curso.
  informacion,

  /// Pendiente, requiere atención, edición bloqueada.
  advertencia,

  /// Error, inconsistencia, eliminación.
  peligro,

  /// Neutral o secundario: no habilitado, cerrado, sin dato.
  neutro,
}

/// Par de colores de un tono: primer plano (ícono y texto) y fondo suave.
@immutable
class ParSemantico {
  const ParSemantico(this.primerPlano, this.fondo);

  final Color primerPlano;
  final Color fondo;

  static ParSemantico lerp(ParSemantico a, ParSemantico b, double t) => ParSemantico(
        Color.lerp(a.primerPlano, b.primerPlano, t)!,
        Color.lerp(a.fondo, b.fondo, t)!,
      );
}

/// Colores semánticos de la App, centralizados en el tema (`Theme.of(context).extension`).
/// Se derivan de [ColoresTribunal]: no se inventan colores nuevos.
@immutable
class ColoresSemanticos extends ThemeExtension<ColoresSemanticos> {
  const ColoresSemanticos({
    required this.exito,
    required this.informacion,
    required this.advertencia,
    required this.peligro,
    required this.neutro,
  });

  final ParSemantico exito;
  final ParSemantico informacion;
  final ParSemantico advertencia;
  final ParSemantico peligro;
  final ParSemantico neutro;

  /// Fondo suave: el color del estado a baja opacidad sobre la superficie.
  static Color _suave(Color color) =>
      Color.alphaBlend(color.withValues(alpha: 0.12), ColoresTribunal.superficie);

  static final ColoresSemanticos claro = ColoresSemanticos(
    exito: ParSemantico(ColoresTribunal.exito, _suave(ColoresTribunal.exito)),
    informacion: ParSemantico(ColoresTribunal.informacion, _suave(ColoresTribunal.informacion)),
    // El amarillo no se lee sobre fondo claro: el texto usa su tono oscuro.
    advertencia: ParSemantico(ColoresTribunal.textoAdvertencia, _suave(ColoresTribunal.advertencia)),
    peligro: ParSemantico(ColoresTribunal.peligro, _suave(ColoresTribunal.peligro)),
    neutro: ParSemantico(ColoresTribunal.secundario, ColoresTribunal.superficie100),
  );

  ParSemantico de(TonoSemantico tono) => switch (tono) {
        TonoSemantico.exito => exito,
        TonoSemantico.informacion => informacion,
        TonoSemantico.advertencia => advertencia,
        TonoSemantico.peligro => peligro,
        TonoSemantico.neutro => neutro,
      };

  @override
  ColoresSemanticos copyWith({
    ParSemantico? exito,
    ParSemantico? informacion,
    ParSemantico? advertencia,
    ParSemantico? peligro,
    ParSemantico? neutro,
  }) =>
      ColoresSemanticos(
        exito: exito ?? this.exito,
        informacion: informacion ?? this.informacion,
        advertencia: advertencia ?? this.advertencia,
        peligro: peligro ?? this.peligro,
        neutro: neutro ?? this.neutro,
      );

  @override
  ColoresSemanticos lerp(ThemeExtension<ColoresSemanticos>? other, double t) {
    if (other is! ColoresSemanticos) return this;
    return ColoresSemanticos(
      exito: ParSemantico.lerp(exito, other.exito, t),
      informacion: ParSemantico.lerp(informacion, other.informacion, t),
      advertencia: ParSemantico.lerp(advertencia, other.advertencia, t),
      peligro: ParSemantico.lerp(peligro, other.peligro, t),
      neutro: ParSemantico.lerp(neutro, other.neutro, t),
    );
  }
}

extension ColoresSemanticosContexto on BuildContext {
  /// Colores semánticos del tema; si no se registró la extensión, los de la App.
  ColoresSemanticos get semanticos =>
      Theme.of(this).extension<ColoresSemanticos>() ?? ColoresSemanticos.claro;
}

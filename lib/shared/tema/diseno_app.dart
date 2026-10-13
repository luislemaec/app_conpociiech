import 'package:flutter/material.dart';

/// Medidas compartidas; el texto conserva el escalado del sistema operativo.
abstract final class DisenoApp {
  static const double xs = 4, sm = 8, md = 16, lg = 24, xl = 32, xxl = 48;
  static const double tablet = 600, grande = 1024, anchoContenido = 1120;

  /// Ancho de lectura de las pantallas institucionales (Inicio, Organización, Servicios).
  static const double anchoLectura = 760;
  static const double radio = 16, radioCampo = 12, radioIcono = 12;

  /// Tamaño mínimo de un área táctil (accesibilidad).
  static const double minimoTactil = 48;

  /// Duraciones de microinteracciones discretas.
  static const Duration rapida = Duration(milliseconds: 120);
  static const Duration estandar = Duration(milliseconds: 220);
  static const Duration entrada = Duration(milliseconds: 400);

  static EdgeInsets margen(double ancho) =>
      EdgeInsets.all(ancho < tablet ? md : lg);
}

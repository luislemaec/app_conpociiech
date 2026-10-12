import 'package:flutter/material.dart';

/// Medidas compartidas; el texto conserva el escalado del sistema operativo.
abstract final class DisenoApp {
  static const double xs = 4, sm = 8, md = 16, lg = 24, xl = 32, xxl = 48;
  static const double tablet = 600, grande = 1024, anchoContenido = 1120;
  static const double radio = 16, radioCampo = 12;
  static EdgeInsets margen(double ancho) =>
      EdgeInsets.all(ancho < tablet ? md : lg);
}

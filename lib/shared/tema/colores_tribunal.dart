import 'package:flutter/material.dart';

/// Colores institucionales tomados del tema Tribunal de TEC
/// (`primefaces-tribunal/theme.css` y `TipografiaPdf.AZUL`). No se inventan colores:
/// cualquier ajuste debe partir de esos tokens para que la App y la web se vean igual.
abstract final class ColoresTribunal {
  /// Azul institucional (`--primary-color`): botones, enlaces y acentos.
  static const Color primario = Color(0xFF034EA2);
  static const Color primario700 = Color(0xFF023875);
  static const Color primario800 = Color(0xFF022D5E);
  static const Color primario100 = Color(0xFFD2DFEE);
  static const Color primario50 = Color(0xFFF0F4F9);

  /// Azul de títulos y documentos oficiales (`TipografiaPdf.AZUL`).
  static const Color azulInstitucional = Color(0xFF004385);

  static const Color textoFuerte = Color(0xFF212529);
  static const Color texto = Color(0xFF495057);
  static const Color textoSecundario = Color(0xFF5F6870);

  static const Color fondo = Color(0xFFF8F9FA);
  static const Color superficie = Color(0xFFFFFFFF);
  static const Color superficie100 = Color(0xFFF5F5F5);
  static const Color borde = Color(0xFFDEE2E6);

  static const Color secundario = Color(0xFF597481);
  static const Color exito = Color(0xFF517C2C);
  static const Color informacion = Color(0xFF0276B6);
  static const Color advertencia = Color(0xFFFBC02D);
  static const Color textoAdvertencia = Color(0xFF8D6C19);
  static const Color peligro = Color(0xFFD32F2F);
  static const Color sobreColor = Color(0xFFFFFFFF);
}

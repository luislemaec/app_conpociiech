import 'package:flutter/material.dart';

import 'colores_tribunal.dart';

/// Tema único de la App con la identidad del Tribunal: Montserrat y colores de
/// [ColoresTribunal]. Pesos del estándar tipográfico de TEC: 400 texto, 500 énfasis,
/// 700 énfasis fuerte.
abstract final class TemaApp {
  static const String familia = 'Montserrat';

  static ThemeData get claro {
    const esquema = ColorScheme(
      brightness: Brightness.light,
      primary: ColoresTribunal.primario,
      onPrimary: ColoresTribunal.sobreColor,
      primaryContainer: ColoresTribunal.primario100,
      onPrimaryContainer: ColoresTribunal.primario800,
      secondary: ColoresTribunal.secundario,
      onSecondary: ColoresTribunal.sobreColor,
      error: ColoresTribunal.peligro,
      onError: ColoresTribunal.sobreColor,
      surface: ColoresTribunal.superficie,
      onSurface: ColoresTribunal.texto,
      onSurfaceVariant: ColoresTribunal.textoSecundario,
      outline: ColoresTribunal.borde,
      outlineVariant: ColoresTribunal.borde,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: esquema,
      fontFamily: familia,
      scaffoldBackgroundColor: ColoresTribunal.fondo,
    );

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        headlineSmall: base.textTheme.headlineSmall?.copyWith(
          color: ColoresTribunal.azulInstitucional,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          color: ColoresTribunal.textoFuerte,
          fontWeight: FontWeight.w500,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          color: ColoresTribunal.textoFuerte,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(color: ColoresTribunal.texto),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(color: ColoresTribunal.texto),
        bodySmall: base.textTheme.bodySmall?.copyWith(color: ColoresTribunal.textoSecundario),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: ColoresTribunal.superficie,
        foregroundColor: ColoresTribunal.azulInstitucional,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: familia,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: ColoresTribunal.azulInstitucional,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          textStyle: const TextStyle(fontFamily: familia, fontSize: 16, fontWeight: FontWeight.w500),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          textStyle: const TextStyle(fontFamily: familia, fontSize: 16, fontWeight: FontWeight.w500),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ColoresTribunal.superficie,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: ColoresTribunal.borde),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: ColoresTribunal.borde),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: ColoresTribunal.primario, width: 1.5),
        ),
      ),
      cardTheme: CardThemeData(
        color: ColoresTribunal.superficie,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: ColoresTribunal.borde),
        ),
      ),
    );
  }
}

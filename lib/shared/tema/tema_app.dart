import 'package:flutter/material.dart';

import 'colores_semanticos.dart';
import 'colores_tribunal.dart';
import 'diseno_app.dart';

/// Tema único de la App con la identidad del Tribunal: Montserrat y colores de
/// [ColoresTribunal]. Pesos del estándar tipográfico de TEC: 400 texto, 500 énfasis,
/// 700 énfasis fuerte.
abstract final class TemaApp {
  static const String familia = 'Montserrat';

  static ThemeData get claro {
    final esquema = ColorScheme.fromSeed(seedColor: ColoresTribunal.primario)
        .copyWith(
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
          outline: ColoresTribunal.textoSecundario,
          outlineVariant: ColoresTribunal.borde,
        );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: esquema,
      fontFamily: familia,
      scaffoldBackgroundColor: ColoresTribunal.fondo,
    );

    // Escala tipográfica única (tamaños lógicos; el sistema los escala según la
    // accesibilidad del dispositivo). Mínimo 13 para texto operativo, sin pesos finos.
    TextStyle? estilo(
      TextStyle? b,
      double tamano,
      FontWeight peso,
      Color color, {
      double? alto,
    }) => b?.copyWith(
      fontSize: tamano,
      fontWeight: peso,
      color: color,
      height: alto,
    );
    final t = base.textTheme;
    final textos = t.copyWith(
      // Título principal de pantalla.
      headlineSmall: estilo(
        t.headlineSmall,
        24,
        FontWeight.w700,
        ColoresTribunal.azulInstitucional,
        alto: 1.25,
      ),
      // Título de sección / encabezado.
      titleLarge: estilo(
        t.titleLarge,
        20,
        FontWeight.w700,
        ColoresTribunal.textoFuerte,
        alto: 1.3,
      ),
      // Título de tarjeta, nombre en listas.
      titleMedium: estilo(
        t.titleMedium,
        16,
        FontWeight.w500,
        ColoresTribunal.textoFuerte,
        alto: 1.35,
      ),
      titleSmall: estilo(
        t.titleSmall,
        15,
        FontWeight.w500,
        ColoresTribunal.textoFuerte,
        alto: 1.35,
      ),
      // Cuerpo.
      bodyLarge: estilo(
        t.bodyLarge,
        16,
        FontWeight.w400,
        ColoresTribunal.texto,
        alto: 1.5,
      ),
      bodyMedium: estilo(
        t.bodyMedium,
        15,
        FontWeight.w400,
        ColoresTribunal.texto,
        alto: 1.45,
      ),
      // Secundario / caption: nunca menos de 13.
      bodySmall: estilo(
        t.bodySmall,
        13,
        FontWeight.w400,
        ColoresTribunal.textoSecundario,
        alto: 1.4,
      ),
      // Botones y etiquetas.
      labelLarge: estilo(
        t.labelLarge,
        15,
        FontWeight.w500,
        ColoresTribunal.textoFuerte,
      ),
      labelMedium: estilo(
        t.labelMedium,
        13,
        FontWeight.w500,
        ColoresTribunal.texto,
      ),
      labelSmall: estilo(
        t.labelSmall,
        13,
        FontWeight.w500,
        ColoresTribunal.textoSecundario,
      ),
    );

    return base.copyWith(
      textTheme: textos,
      extensions: [ColoresSemanticos.claro],
      chipTheme: ChipThemeData(
        labelStyle: textos.labelMedium,
        side: const BorderSide(color: ColoresTribunal.borde),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DisenoApp.radioCampo),
        ),
      ),
      listTileTheme: ListTileThemeData(
        titleTextStyle: textos.titleMedium,
        subtitleTextStyle: textos.bodySmall,
        minVerticalPadding: DisenoApp.sm + DisenoApp.xs,
      ),
      dividerTheme: const DividerThemeData(
        color: ColoresTribunal.borde,
        space: 1,
        thickness: 1,
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
          textStyle: const TextStyle(
            fontFamily: familia,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DisenoApp.radioCampo),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          textStyle: const TextStyle(
            fontFamily: familia,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DisenoApp.radioCampo),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ColoresTribunal.superficie,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DisenoApp.radioCampo),
          borderSide: const BorderSide(color: ColoresTribunal.borde),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DisenoApp.radioCampo),
          borderSide: const BorderSide(color: ColoresTribunal.borde),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DisenoApp.radioCampo),
          borderSide: const BorderSide(
            color: ColoresTribunal.primario,
            width: 1.5,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DisenoApp.radio),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(showDragHandle: true),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: ColoresTribunal.superficie,
        indicatorColor: ColoresTribunal.primario100,
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: ColoresTribunal.superficie,
        indicatorColor: ColoresTribunal.primario100,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      cardTheme: CardThemeData(
        color: ColoresTribunal.superficie,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DisenoApp.radio),
          side: const BorderSide(color: ColoresTribunal.borde),
        ),
      ),
    );
  }
}

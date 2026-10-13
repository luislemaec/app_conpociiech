import 'package:flutter/material.dart';

/// Símbolo oficial de CONPOCIIECH (organización), sin la palabra «CONPOCIIECH»: Inicio,
/// Organización y barra superior. El nombre se muestra como texto de la interfaz. PNG
/// con transparencia real (sin fondo blanco); el contorno claro del sello es parte del
/// diseño. Original con texto en `branding/logo_conpociiech_original.png` (no se
/// empaqueta). Normalización: `branding/normalizar_logo.ps1`.
class LogoInstitucional extends StatelessWidget {
  const LogoInstitucional({super.key, this.ancho = 220});

  static const String ruta = 'assets/branding/logo_conpociiech.png';

  /// Alto / ancho de la imagen (468 x 465 px): reserva el espacio antes de decodificarla.
  static const double proporcion = 465 / 468;

  final double ancho;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      ruta,
      width: ancho,
      height: ancho * proporcion,
      fit: BoxFit.contain,
      semanticLabel: 'CONPOCIIECH',
    );
  }
}

/// Logo del TEC – Tribunal Electoral CONPOCIIECH: inicio de sesión y módulo Tribunal,
/// porque las credenciales y la información electoral pertenecen al sistema TEC.
class LogoTribunal extends StatelessWidget {
  const LogoTribunal({super.key, this.ancho = 220});

  static const String ruta = 'assets/branding/logo_tec.png';

  /// Alto / ancho de la imagen (1744 x 937 px).
  static const double proporcion = 937 / 1744;

  final double ancho;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      ruta,
      width: ancho,
      height: ancho * proporcion,
      fit: BoxFit.contain,
      semanticLabel: 'TEC – Tribunal Electoral CONPOCIIECH',
    );
  }
}

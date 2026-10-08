import 'package:flutter/material.dart';

/// Logo de la App. PROVISIONAL: usa el logo del TEC – Tribunal Electoral hasta contar
/// con el logo oficial de CONPOCIIECH como organización; al recibirlo basta con
/// reemplazar [ruta] y la imagen en assets/branding/.
class LogoInstitucional extends StatelessWidget {
  const LogoInstitucional({super.key, this.ancho = 220});

  static const String ruta = 'assets/branding/logo_tec_provisional.png';

  final double ancho;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      ruta,
      width: ancho,
      fit: BoxFit.contain,
      semanticLabel: 'TEC – Tribunal Electoral CONPOCIIECH',
    );
  }
}

import 'package:flutter/foundation.dart';

/// Ambiente al que apunta la App.
enum Ambiente {
  desarrollo('DESARROLLO'),
  produccion('PRODUCCION');

  const Ambiente(this.clave);

  /// Valor de `AMBIENTE` en los archivos de `config/`.
  final String clave;

  static Ambiente desdeClave(String clave) {
    final normalizada = clave.trim().toUpperCase();
    for (final a in values) {
      if (a.clave == normalizada) return a;
    }
    throw ArgumentError.value(clave, 'AMBIENTE', 'debe ser DESARROLLO o PRODUCCION');
  }
}

/// Configuración única de la App (la «AppConfig»): ambiente y URL base de la API de TEC.
/// `ClienteApi` la recibe y todos los servicios (`ApiAutenticacion`, `ApiTribunal`,
/// avisos push) la usan; no hay URLs en otros archivos. Se recibe al compilar con
/// `--dart-define-from-file`, nunca con secretos:
///
/// - Producción: `flutter build appbundle --dart-define-from-file=config/produccion.json`
/// - Desarrollo: `flutter run --dart-define-from-file=config/desarrollo.json`
///
/// Sin archivo se usa producción (valor seguro para un APK publicado); en debug la
/// pantalla de inicio de sesión muestra a qué ambiente apunta.
class Entorno {
  const Entorno._(this.ambiente, this.apiBaseUrl, this.caDesarrollo);

  final Ambiente ambiente;

  /// URL base de la API de TEC. Solo HTTPS: la información electoral no viaja en claro.
  final Uri apiBaseUrl;

  /// Certificado de una CA local de desarrollo (mkcert) en la que se confía además de las
  /// CA del sistema. Solo en DESARROLLO y fuera de release: el APK publicado nunca confía
  /// en una CA local.
  final String? caDesarrollo;

  static const String urlPorDefecto = 'https://tribunal.conpociiech.org/api/v1';

  bool get esProduccion => ambiente == Ambiente.produccion;

  factory Entorno.desdeDefinicion() => Entorno.desdeUrl(
    const String.fromEnvironment('API_BASE_URL', defaultValue: urlPorDefecto),
    ambiente: Ambiente.desdeClave(
      const String.fromEnvironment('AMBIENTE', defaultValue: 'PRODUCCION'),
    ),
    caDesarrollo: const String.fromEnvironment('CA_DESARROLLO'),
  );

  /// Valida la URL: debe ser absoluta y HTTPS; si no, la App no arranca con una
  /// configuración insegura.
  factory Entorno.desdeUrl(
    String url, {
    Ambiente ambiente = Ambiente.produccion,
    String? caDesarrollo,
    bool release = kReleaseMode,
  }) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasAuthority || uri.scheme != 'https') {
      throw ArgumentError.value(
        url,
        'API_BASE_URL',
        'debe ser una URL https absoluta',
      );
    }
    final ca = caDesarrollo?.trim();
    final usarCa = !release && ambiente == Ambiente.desarrollo && ca != null && ca.isNotEmpty;
    return Entorno._(ambiente, uri, usarCa ? ca : null);
  }

  /// Texto para identificar el ambiente en pantalla (solo fuera de producción o en debug).
  String get descripcion =>
      '${esProduccion ? 'Producción' : 'Desarrollo'} · ${apiBaseUrl.host}';
}

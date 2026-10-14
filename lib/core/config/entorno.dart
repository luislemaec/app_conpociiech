import 'package:flutter/foundation.dart';

/// Configuración de la App por entorno, recibida al compilar con `--dart-define`
/// (nunca hay secretos ni API keys en el código).
///
/// Ejemplo:
/// `flutter run --dart-define=API_BASE_URL=https://tribunal.conpociiech.org/api/v1`
///
/// Desarrollo contra TEC en la PC: `flutter run --dart-define-from-file=entorno_local.json`
/// (ver README, «Probar contra TEC local»).
class Entorno {
  const Entorno._(this.apiBaseUrl, this.caDesarrollo);

  /// URL base de la API de TEC. Solo HTTPS: la información electoral no viaja en claro.
  final Uri apiBaseUrl;

  /// Certificado PEM de una CA local de desarrollo (mkcert) en la que se confía además
  /// de las CA del sistema. Siempre `null` en compilaciones release: el APK publicado
  /// nunca confía en una CA local.
  final String? caDesarrollo;

  static const String urlPorDefecto = 'https://tribunal.conpociiech.org/api/v1';

  factory Entorno.desdeDefinicion() => Entorno.desdeUrl(
    const String.fromEnvironment('API_BASE_URL', defaultValue: urlPorDefecto),
    caDesarrollo: const String.fromEnvironment('CA_DESARROLLO'),
  );

  /// Valida la URL: debe ser absoluta y HTTPS; si no, la App no arranca con una
  /// configuración insegura.
  factory Entorno.desdeUrl(
    String url, {
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
    return Entorno._(uri, release || ca == null || ca.isEmpty ? null : ca);
  }
}

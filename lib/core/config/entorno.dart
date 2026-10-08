/// Configuración de la App por entorno, recibida al compilar con `--dart-define`
/// (nunca hay secretos ni API keys en el código).
///
/// Ejemplo:
/// `flutter run --dart-define=API_BASE_URL=https://tribunal.conpociiech.org/api/v1`
class Entorno {
  const Entorno._(this.apiBaseUrl);

  /// URL base de la API de TEC. Solo HTTPS: la información electoral no viaja en claro.
  final Uri apiBaseUrl;

  static const String urlPorDefecto = 'https://tribunal.conpociiech.org/api/v1';

  factory Entorno.desdeDefinicion() =>
      Entorno.desdeUrl(const String.fromEnvironment('API_BASE_URL', defaultValue: urlPorDefecto));

  /// Valida la URL: debe ser absoluta y HTTPS; si no, la App no arranca con una
  /// configuración insegura.
  factory Entorno.desdeUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasAuthority || uri.scheme != 'https') {
      throw ArgumentError.value(url, 'API_BASE_URL', 'debe ser una URL https absoluta');
    }
    return Entorno._(uri);
  }
}

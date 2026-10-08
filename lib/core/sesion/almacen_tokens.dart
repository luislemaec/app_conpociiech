import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Guarda solo el refresh token, cifrado por el sistema (Android Keystore / iOS Keychain).
/// El token de acceso vive solo en memoria y la contraseña nunca se guarda.
abstract class AlmacenTokens {
  Future<String?> leerRefresh();

  Future<void> guardarRefresh(String refreshToken);

  Future<void> borrar();
}

class AlmacenTokensSeguro implements AlmacenTokens {
  AlmacenTokensSeguro()
      : _almacen = const FlutterSecureStorage(
          // Sin copia en iCloud ni en otro dispositivo.
          iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
        );

  static const String _clave = 'tec.refresh_token';

  final FlutterSecureStorage _almacen;

  @override
  Future<String?> leerRefresh() => _almacen.read(key: _clave);

  @override
  Future<void> guardarRefresh(String refreshToken) => _almacen.write(key: _clave, value: refreshToken);

  @override
  Future<void> borrar() => _almacen.delete(key: _clave);
}

/// Para pruebas: no persiste nada fuera de la memoria.
class AlmacenTokensMemoria implements AlmacenTokens {
  String? refresh;

  @override
  Future<String?> leerRefresh() async => refresh;

  @override
  Future<void> guardarRefresh(String refreshToken) async => refresh = refreshToken;

  @override
  Future<void> borrar() async => refresh = null;
}

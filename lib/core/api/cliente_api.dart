import 'dart:async';
import 'dart:convert';
import 'dart:io' show IOException;

import 'package:http/http.dart' as http;

/// Respuesta de error de la API de TEC (`{codigo, mensaje}`, docs/api-movil.md).
class ErrorApi implements Exception {
  const ErrorApi(this.estado, this.codigo, this.mensaje);

  final int estado;
  final String codigo;

  /// Texto en español apto para mostrar al usuario (lo redacta TEC).
  final String mensaje;

  bool get noAutenticado => estado == 401;

  @override
  String toString() => 'ErrorApi($estado, $codigo)';
}

/// No se pudo contactar con TEC (sin red, DNS, TLS o tiempo agotado).
class SinConexion implements Exception {
  const SinConexion();

  static const String mensaje = 'No se pudo conectar con el sistema TEC. Revise su conexión e inténtelo de nuevo.';
}

/// Cliente JSON de bajo nivel para la API de TEC. No conoce la sesión: el token lo
/// recibe por petición. Nunca registra cuerpos ni cabeceras (claves y tokens).
class ClienteApi {
  ClienteApi(this._base, {http.Client? cliente, this.tiempoMaximo = const Duration(seconds: 20)})
      : _cliente = cliente ?? http.Client();

  final Uri _base;
  final http.Client _cliente;
  final Duration tiempoMaximo;

  static const String _mensajeGenerico = 'No se pudo completar la solicitud. Inténtelo más tarde.';

  /// Envía la petición y devuelve el objeto JSON de la respuesta (o `null` si no hay cuerpo).
  /// Lanza [ErrorApi] ante un estado de error y [SinConexion] si no hubo respuesta.
  Future<Map<String, dynamic>?> enviar(String metodo, String ruta, {Object? cuerpo, String? token}) async {
    final json = await _enviar(metodo, ruta, cuerpo: cuerpo, token: token);
    return json is Map<String, dynamic> ? json : null;
  }

  /// Igual que [enviar] para respuestas que son una lista JSON.
  Future<List<dynamic>> enviarLista(String metodo, String ruta, {Object? cuerpo, String? token}) async {
    final json = await _enviar(metodo, ruta, cuerpo: cuerpo, token: token);
    return json is List<dynamic> ? json : const [];
  }

  /// [ruta] es relativa a la URL base y puede llevar parámetros (`/x?pagina=0`).
  Future<Object?> _enviar(String metodo, String ruta, {Object? cuerpo, String? token}) async {
    final relativa = Uri.parse(ruta);
    final url = _base.replace(path: '${_base.path}${relativa.path}', query: relativa.hasQuery ? relativa.query : null);
    final peticion = http.Request(metodo, url)
      ..headers['Accept'] = 'application/json';
    if (token != null) peticion.headers['Authorization'] = 'Bearer $token';
    if (cuerpo != null) {
      peticion.headers['Content-Type'] = 'application/json; charset=utf-8';
      peticion.body = jsonEncode(cuerpo);
    }

    final http.Response respuesta;
    try {
      respuesta = await http.Response.fromStream(await _cliente.send(peticion).timeout(tiempoMaximo));
    } on TimeoutException {
      throw const SinConexion();
    } on http.ClientException {
      throw const SinConexion();
    } on IOException {
      throw const SinConexion();
    }

    final json = _json(respuesta);
    if (respuesta.statusCode >= 200 && respuesta.statusCode < 300) return json;
    final error = json is Map<String, dynamic> ? json : null;
    throw ErrorApi(
      respuesta.statusCode,
      error?['codigo'] as String? ?? 'ERROR_${respuesta.statusCode}',
      error?['mensaje'] as String? ?? _mensajeGenerico,
    );
  }

  void cerrar() => _cliente.close();

  static Object? _json(http.Response respuesta) {
    if (respuesta.bodyBytes.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(respuesta.bodyBytes));
    } on FormatException {
      // Por ejemplo, una página HTML del proxy: se trata como respuesta sin datos.
      return null;
    }
  }
}

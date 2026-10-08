import 'package:flutter/foundation.dart';

import '../api/cliente_api.dart';

/// Perfil que devuelve TEC (`usuario` en las respuestas de sesión y `/auth/yo`).
@immutable
class PerfilUsuario {
  const PerfilUsuario({required this.usuario, required this.nombre, required this.roles, this.iglesiaId});

  factory PerfilUsuario.desdeJson(Map<String, dynamic> json) => PerfilUsuario(
        usuario: json['usuario'] as String,
        nombre: json['nombre'] as String? ?? json['usuario'] as String,
        roles: Set.unmodifiable((json['roles'] as List<dynamic>? ?? const []).cast<String>()),
        iglesiaId: json['iglesiaId'] as int?,
      );

  final String usuario;
  final String nombre;

  /// Roles TEC del usuario; la App recibe la unión de permisos de todos ellos.
  final Set<String> roles;
  final int? iglesiaId;
}

/// Par de tokens emitido por TEC. El de acceso vive 5 minutos; el refresh rota en cada uso.
@immutable
class SesionTec {
  const SesionTec({
    required this.accessToken,
    required this.refreshToken,
    required this.accesoExpiraEn,
    required this.cambioClaveObligatorio,
    required this.perfil,
  });

  factory SesionTec.desdeJson(Map<String, dynamic> json, DateTime ahora) => SesionTec(
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String,
        accesoExpiraEn: ahora.add(Duration(seconds: (json['expiraEnSegundos'] as num).toInt())),
        cambioClaveObligatorio: json['cambioClaveObligatorio'] as bool? ?? false,
        perfil: PerfilUsuario.desdeJson(json['usuario'] as Map<String, dynamic>),
      );

  final String accessToken;
  final String refreshToken;
  final DateTime accesoExpiraEn;
  final bool cambioClaveObligatorio;
  final PerfilUsuario perfil;
}

/// Endpoints `/auth/*` de TEC (docs/api-movil.md en el repositorio de TEC).
class ApiAutenticacion {
  ApiAutenticacion(this._cliente, {DateTime Function()? reloj}) : _reloj = reloj ?? DateTime.now;

  final ClienteApi _cliente;
  final DateTime Function() _reloj;

  Future<SesionTec> iniciarSesion(String usuario, String clave, {String? dispositivo}) async =>
      _sesion(await _cliente.enviar('POST', '/auth/login',
          cuerpo: {'usuario': usuario, 'clave': clave, 'dispositivo': ?dispositivo}));

  Future<SesionTec> renovar(String refreshToken) async =>
      _sesion(await _cliente.enviar('POST', '/auth/refresh', cuerpo: {'refreshToken': refreshToken}));

  Future<PerfilUsuario> yo(String accessToken) async =>
      PerfilUsuario.desdeJson((await _cliente.enviar('GET', '/auth/yo', token: accessToken))!);

  /// Cambia la clave; TEC revoca todas las sesiones del usuario y entrega una nueva.
  Future<SesionTec> cambiarClave(String accessToken, String claveActual, String claveNueva) async =>
      _sesion(await _cliente.enviar('POST', '/auth/cambiar-clave',
          token: accessToken, cuerpo: {'claveActual': claveActual, 'claveNueva': claveNueva}));

  Future<void> cerrarSesion(String accessToken) => _cliente.enviar('POST', '/auth/logout', token: accessToken);

  SesionTec _sesion(Map<String, dynamic>? json) {
    if (json == null) throw const ErrorApi(500, 'RESPUESTA_INVALIDA', 'Respuesta inesperada del sistema TEC.');
    return SesionTec.desdeJson(json, _reloj());
  }
}

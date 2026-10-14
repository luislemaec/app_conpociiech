import 'dart:async';

import 'package:flutter/foundation.dart';

import '../api/cliente_api.dart';
import '../sesion/sesion_controller.dart';
import 'proveedor_push.dart';

/// Une las notificaciones push con la sesión de TEC:
/// - con una sesión completa, registra el token del dispositivo en TEC (y cada vez que cambia);
/// - antes de que el usuario cierre sesión, lo da de baja para no recibir avisos de otra cuenta;
/// - publica los avisos recibidos y los tocados para que la App los muestre o navegue.
class ControladorPush {
  ControladorPush({
    required this.proveedor,
    required this.sesion,
    required this.cliente,
  }) {
    sesion.addListener(_alCambiarSesion);
    sesion.alCerrarSesion(_darDeBaja);
    _suscripciones.add(
      proveedor.tokenRenovado.listen((token) {
        _token = token;
        _registradoPara = null;
        _alCambiarSesion();
      }),
    );
    _alCambiarSesion();
  }

  final ProveedorPush proveedor;
  final SesionController sesion;
  final ClienteApi cliente;

  final List<StreamSubscription<Object?>> _suscripciones = [];
  String? _token;

  /// Usuario para el que ya se registró el token actual (evita registrarlo en cada cambio).
  String? _registradoPara;
  bool _registrando = false;

  Stream<AvisoPush> get avisoRecibido => proveedor.avisoRecibido;
  Stream<AvisoPush> get avisoAbierto => proveedor.avisoAbierto;

  Future<void> _alCambiarSesion() async {
    final usuario = sesion.perfil?.usuario;
    if (!sesion.autenticado ||
        sesion.cambioClaveObligatorio ||
        usuario == null) {
      _registradoPara = null;
      return;
    }
    if (_registrando || _registradoPara == usuario) return;
    _registrando = true;
    try {
      _token ??= await proveedor.obtenerToken();
      final token = _token;
      if (token == null) return;
      await sesion.autenticada(
        (acceso) => cliente.enviar(
          'POST',
          '/dispositivos',
          token: acceso,
          cuerpo: {'token': token, 'plataforma': proveedor.plataforma},
        ),
      );
      _registradoPara = usuario;
    } on ErrorApi catch (e) {
      debugPrint(
        'No se pudo registrar el dispositivo para avisos (${e.codigo}).',
      );
    } on SinConexion {
      // Se reintenta en el próximo cambio de sesión o renovación del token.
    } catch (e) {
      debugPrint('Notificaciones no disponibles (${e.runtimeType}).');
    } finally {
      _registrando = false;
    }
  }

  Future<void> _darDeBaja() async {
    final token = _token;
    _registradoPara = null;
    if (token == null) return;
    await sesion.autenticada(
      (acceso) => cliente.enviar(
        'POST',
        '/dispositivos/baja',
        token: acceso,
        cuerpo: {'token': token},
      ),
    );
  }

  void dispose() {
    sesion.removeListener(_alCambiarSesion);
    for (final s in _suscripciones) {
      s.cancel();
    }
  }
}

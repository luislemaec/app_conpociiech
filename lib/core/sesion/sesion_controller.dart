import 'dart:async';

import 'package:flutter/foundation.dart';

import '../api/cliente_api.dart';
import 'almacen_tokens.dart';
import 'api_autenticacion.dart';
import 'roles.dart';

/// Estado de la sesión con TEC (docs/api-movil.md en el repositorio de TEC):
/// - token de acceso de 5 minutos solo en memoria; refresh rotativo cifrado en el dispositivo;
/// - 15 minutos de inactividad, igual que la web: al superarlos la sesión se cierra en la
///   siguiente interacción o al volver a la App;
/// - un usuario no permanente solo puede cambiar su clave hasta hacerlo.
/// La contraseña nunca se guarda.
class SesionController extends ChangeNotifier {
  SesionController({
    required this._api,
    required this._almacen,
    DateTime Function()? reloj,
    this.dispositivo,
  })  : _reloj = reloj ?? DateTime.now;

  /// Igual que el session-timeout de la web.
  static const Duration inactividad = Duration(minutes: 15);

  /// Con actividad en pantalla pero sin peticiones, renueva para que TEC no expire la sesión.
  static const Duration mantenerViva = Duration(minutes: 10);

  /// Margen para renovar el token de acceso antes de que venza.
  static const Duration margenAcceso = Duration(seconds: 30);

  static const String avisoInactividad = 'Su sesión se cerró por inactividad. Inicie sesión nuevamente.';
  static const String avisoExpirada = 'Su sesión expiró. Inicie sesión nuevamente.';

  final ApiAutenticacion _api;
  final AlmacenTokens _almacen;
  final DateTime Function() _reloj;

  /// Descripción genérica del dispositivo para la auditoría de TEC (sin identificadores).
  final String? dispositivo;

  SesionTec? _sesion;
  DateTime _ultimaActividad = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _ultimoContacto = DateTime.fromMillisecondsSinceEpoch(0);
  Future<bool>? _renovacion;
  String? _aviso;

  bool get autenticado => _sesion != null;

  PerfilUsuario? get perfil => _sesion?.perfil;

  String? get nombreUsuario => _sesion?.perfil.nombre;

  Set<String> get roles => _sesion?.perfil.roles ?? const {};

  bool get cambioClaveObligatorio => _sesion?.cambioClaveObligatorio ?? false;

  bool tieneAlgunRol(Iterable<String> requeridos) => requeridos.any(roles.contains);

  /// Unión de permisos: basta con uno de los roles del módulo.
  bool get puedeAccederTribunal => autenticado && !cambioClaveObligatorio && tieneAlgunRol(RolTec.moduloTribunal);

  /// Motivo del último cierre automático; se muestra una sola vez.
  String? consumirAviso() {
    final aviso = _aviso;
    _aviso = null;
    return aviso;
  }

  /// Recupera la sesión guardada al abrir la App. Sin conexión conserva el refresh para
  /// intentarlo más tarde; si TEC lo rechaza, lo borra.
  Future<void> restaurar() async {
    final refresh = await _almacen.leerRefresh();
    if (refresh == null) return;
    try {
      await _establecer(await _api.renovar(refresh));
    } on ErrorApi {
      await _almacen.borrar();
    } on SinConexion {
      // Se reintentará en el próximo arranque o con un nuevo inicio de sesión.
    }
  }

  /// Lanza [ErrorApi] (credenciales, límite de intentos…) o [SinConexion].
  Future<void> iniciarSesion(String usuario, String clave) async {
    _aviso = null;
    await _establecer(await _api.iniciarSesion(usuario.trim(), clave, dispositivo: dispositivo));
  }

  /// Cambia la clave con la sesión vigente; TEC entrega una sesión completa nueva.
  Future<void> cambiarClave(String claveActual, String claveNueva) async {
    final nueva = await autenticada((token) => _api.cambiarClave(token, claveActual, claveNueva));
    await _establecer(nueva);
  }

  /// Cierre por el usuario: borra lo local y revoca en TEC si hay conexión.
  Future<void> cerrar() async {
    final sesion = _sesion;
    if (sesion == null) return;
    await _limpiar();
    try {
      await _api.cerrarSesion(sesion.accessToken);
    } on ErrorApi {
      // Token ya vencido o revocado: la sesión expira sola en TEC.
    } on SinConexion {
      // Ídem: TEC la cierra por inactividad.
    }
  }

  /// Ejecuta una petición protegida: renueva el token si venció y reintenta una vez ante
  /// un 401. Si la sesión ya no es válida, la cierra y propaga el error.
  Future<T> autenticada<T>(Future<T> Function(String accessToken) peticion) async {
    if (_verificarInactividad()) throw const ErrorApi(401, 'SESION_INVALIDA', avisoInactividad);
    final sesion = _sesion;
    if (sesion == null) throw const ErrorApi(401, 'SESION_INVALIDA', avisoExpirada);
    if (!_reloj().isBefore(sesion.accesoExpiraEn.subtract(margenAcceso)) && !await _renovar()) {
      throw const ErrorApi(401, 'SESION_INVALIDA', avisoExpirada);
    }
    try {
      return await _conContacto(peticion(_sesion!.accessToken));
    } on ErrorApi catch (e) {
      if (!e.noAutenticado || !await _renovar()) rethrow;
      return _conContacto(peticion(_sesion!.accessToken));
    }
  }

  /// Llamar ante cada interacción del usuario. Cierra la sesión si estuvo inactiva más de
  /// 15 minutos y, si no, la mantiene viva en TEC.
  void registrarActividad() {
    if (!autenticado || _verificarInactividad()) return;
    final ahora = _reloj();
    _ultimaActividad = ahora;
    if (ahora.difference(_ultimoContacto) >= mantenerViva) unawaited(_renovar());
  }

  bool _verificarInactividad() {
    if (!autenticado || _reloj().difference(_ultimaActividad) < inactividad) return false;
    _expirar(avisoInactividad);
    return true;
  }

  /// Una sola renovación a la vez: el refresh rota y presentarlo dos veces revocaría la sesión.
  Future<bool> _renovar() => _renovacion ??= _renovarUnaVez().whenComplete(() => _renovacion = null);

  Future<bool> _renovarUnaVez() async {
    final sesion = _sesion;
    if (sesion == null) return false;
    try {
      final nueva = await _api.renovar(sesion.refreshToken);
      // La sesión se cerró mientras tanto: no se resucita.
      if (!identical(_sesion, sesion)) return false;
      await _establecer(nueva);
      return true;
    } on ErrorApi {
      if (identical(_sesion, sesion)) _expirar(avisoExpirada);
      return false;
    } on SinConexion {
      return false;
    }
  }

  Future<T> _conContacto<T>(Future<T> peticion) async {
    final resultado = await peticion;
    _ultimoContacto = _reloj();
    return resultado;
  }

  Future<void> _establecer(SesionTec sesion) async {
    // Primero se guarda el refresh nuevo: el anterior ya no sirve en TEC.
    await _almacen.guardarRefresh(sesion.refreshToken);
    final ahora = _reloj();
    _sesion = sesion;
    _ultimaActividad = ahora;
    _ultimoContacto = ahora;
    notifyListeners();
  }

  void _expirar(String aviso) {
    _aviso = aviso;
    unawaited(_limpiar());
  }

  Future<void> _limpiar() async {
    _sesion = null;
    notifyListeners();
    await _almacen.borrar();
  }
}

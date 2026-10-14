import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Aviso recibido con la App abierta o tocado por el usuario.
class AvisoPush {
  const AvisoPush({this.titulo, this.cuerpo, this.ruta});

  final String? titulo;
  final String? cuerpo;

  /// Pantalla interna que se abre al tocar el aviso (la valida la guarda de rutas).
  final String? ruta;
}

/// Origen de las notificaciones push. La App funciona igual sin él: [ProveedorPushInactivo]
/// se usa cuando Firebase no está configurado y en las pruebas.
abstract class ProveedorPush {
  /// Pide permiso y devuelve el token del dispositivo, o `null` si no hay permiso o Firebase.
  Future<String?> obtenerToken();

  /// El token cambió (Firebase lo renueva periódicamente): hay que registrarlo de nuevo.
  Stream<String> get tokenRenovado;

  /// Avisos recibidos con la App en primer plano.
  Stream<AvisoPush> get avisoRecibido;

  /// Avisos tocados por el usuario (con la App en segundo plano o cerrada).
  Stream<AvisoPush> get avisoAbierto;

  String get plataforma;
}

class ProveedorPushInactivo implements ProveedorPush {
  const ProveedorPushInactivo();

  @override
  Future<String?> obtenerToken() async => null;

  @override
  Stream<String> get tokenRenovado => const Stream.empty();

  @override
  Stream<AvisoPush> get avisoRecibido => const Stream.empty();

  @override
  Stream<AvisoPush> get avisoAbierto => const Stream.empty();

  @override
  String get plataforma =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
}

/// Opciones de Firebase recibidas al compilar con `--dart-define` (no son secretas, pero no
/// se versionan para no fijar un proyecto). Si falta alguna, las notificaciones quedan
/// desactivadas y la App funciona igual.
class ConfiguracionFirebase {
  static FirebaseOptions? desdeDefinicion() {
    const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
    const proyecto = String.fromEnvironment('FIREBASE_PROJECT_ID');
    const remitente = String.fromEnvironment('FIREBASE_SENDER_ID');
    const appAndroid = String.fromEnvironment('FIREBASE_APP_ID_ANDROID');
    const appIos = String.fromEnvironment('FIREBASE_APP_ID_IOS');
    final appId = defaultTargetPlatform == TargetPlatform.iOS
        ? appIos
        : appAndroid;
    if (apiKey.isEmpty ||
        proyecto.isEmpty ||
        remitente.isEmpty ||
        appId.isEmpty)
      return null;
    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: remitente,
      projectId: proyecto,
      iosBundleId: 'ec.org.conpociiech.app',
    );
  }
}

class ProveedorPushFirebase implements ProveedorPush {
  ProveedorPushFirebase._();

  /// Inicializa Firebase; devuelve el proveedor inactivo si no está configurado o falla.
  static Future<ProveedorPush> iniciar() async {
    final opciones = ConfiguracionFirebase.desdeDefinicion();
    if (opciones == null || kIsWeb) return const ProveedorPushInactivo();
    try {
      await Firebase.initializeApp(options: opciones);
      return ProveedorPushFirebase._();
    } catch (e) {
      debugPrint(
        'Notificaciones desactivadas: no se pudo inicializar Firebase (${e.runtimeType}).',
      );
      return const ProveedorPushInactivo();
    }
  }

  FirebaseMessaging get _mensajeria => FirebaseMessaging.instance;

  @override
  Future<String?> obtenerToken() async {
    final permiso = await _mensajeria.requestPermission();
    if (permiso.authorizationStatus == AuthorizationStatus.denied) return null;
    return _mensajeria.getToken();
  }

  @override
  Stream<String> get tokenRenovado => _mensajeria.onTokenRefresh;

  @override
  Stream<AvisoPush> get avisoRecibido =>
      FirebaseMessaging.onMessage.map(_aviso);

  @override
  Stream<AvisoPush> get avisoAbierto async* {
    final inicial = await _mensajeria.getInitialMessage();
    if (inicial != null) yield _aviso(inicial);
    yield* FirebaseMessaging.onMessageOpenedApp.map(_aviso);
  }

  @override
  String get plataforma =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

  static AvisoPush _aviso(RemoteMessage m) => AvisoPush(
    titulo: m.notification?.title,
    cuerpo: m.notification?.body,
    ruta: m.data['ruta'] as String?,
  );
}

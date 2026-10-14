import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/api/cliente_api.dart';
import 'core/api/cliente_http.dart';
import 'core/config/entorno.dart';
import 'core/push/controlador_push.dart';
import 'core/push/proveedor_push.dart';
import 'core/router/app_router.dart';
import 'core/sesion/almacen_tokens.dart';
import 'core/sesion/api_autenticacion.dart';
import 'core/sesion/sesion_controller.dart';
import 'features/tribunal/api_tribunal.dart';
import 'shared/tema/tema_app.dart';

/// Raíz de la App: entorno, sesión con TEC, notificaciones y navegación con guardas.
class AppConpociiech extends StatefulWidget {
  const AppConpociiech({
    super.key,
    required this.entorno,
    this.sesion,
    this.cliente,
    this.proveedorPush = const ProveedorPushInactivo(),
  });

  final Entorno entorno;

  /// Permiten inyectar la sesión y el cliente HTTP en pruebas.
  final SesionController? sesion;
  final ClienteApi? cliente;

  /// Firebase si está configurado; inactivo (sin avisos) en caso contrario y en pruebas.
  final ProveedorPush proveedorPush;

  @override
  State<AppConpociiech> createState() => _AppConpociiechState();
}

class _AppConpociiechState extends State<AppConpociiech> {
  late final ClienteApi _cliente =
      widget.cliente ??
      ClienteApi(
        widget.entorno.apiBaseUrl,
        cliente: crearClienteHttp(caDesarrollo: widget.entorno.caDesarrollo),
      );
  late final SesionController _sesion =
      widget.sesion ??
      (SesionController(
        api: ApiAutenticacion(_cliente),
        almacen: AlmacenTokensSeguro(),
        dispositivo: 'App CONPOCIIECH (${defaultTargetPlatform.name})',
      )..restaurar());
  late final ApiTribunal _apiTribunal = ApiTribunal(_cliente, _sesion);
  late final GoRouter _router = crearRouter(_sesion);
  late final AppLifecycleListener _ciclo;
  late final ControladorPush _push;
  final _mensajes = GlobalKey<ScaffoldMessengerState>();
  final List<StreamSubscription<AvisoPush>> _avisos = [];

  @override
  void initState() {
    super.initState();
    // Al volver a la App se comprueba la inactividad (15 minutos, como la web).
    _ciclo = AppLifecycleListener(onResume: () => _sesion.registrarActividad());
    _push = ControladorPush(
      proveedor: widget.proveedorPush,
      sesion: _sesion,
      cliente: _cliente,
    );
    _avisos
      ..add(_push.avisoRecibido.listen(_mostrarAviso))
      ..add(_push.avisoAbierto.listen((aviso) => _abrir(aviso.ruta)));
  }

  /// Aviso con la App abierta: se muestra sin interrumpir; «Ver» abre la pantalla.
  void _mostrarAviso(AvisoPush aviso) {
    final texto = [aviso.titulo, aviso.cuerpo].whereType<String>().join(': ');
    if (texto.isEmpty) return;
    _mensajes.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(texto),
          duration: const Duration(seconds: 6),
          action: aviso.ruta == null
              ? null
              : SnackBarAction(
                  label: 'Ver',
                  onPressed: () => _abrir(aviso.ruta),
                ),
        ),
      );
  }

  /// Solo rutas internas conocidas; la guarda exige sesión y rol como en cualquier navegación.
  void _abrir(String? ruta) {
    if (ruta != null) _router.go(destinoSeguro(ruta, _sesion));
  }

  @override
  void dispose() {
    for (final s in _avisos) {
      s.cancel();
    }
    _push.dispose();
    _ciclo.dispose();
    _router.dispose();
    if (widget.sesion == null) _sesion.dispose();
    if (widget.cliente == null) _cliente.cerrar();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<Entorno>.value(value: widget.entorno),
        ChangeNotifierProvider<SesionController>.value(value: _sesion),
        Provider<ApiTribunal>.value(value: _apiTribunal),
      ],
      child: MaterialApp.router(
        title: 'CONPOCIIECH',
        debugShowCheckedModeBanner: false,
        theme: TemaApp.claro,
        routerConfig: _router,
        scaffoldMessengerKey: _mensajes,
        // Cualquier toque cuenta como actividad del usuario.
        builder: (context, hijo) => Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => _sesion.registrarActividad(),
          child: hijo,
        ),
      ),
    );
  }
}

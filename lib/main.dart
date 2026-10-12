import 'package:flutter/material.dart';

import 'app.dart';
import 'core/config/entorno.dart';
import 'core/push/proveedor_push.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Falla al arrancar si API_BASE_URL no es https: nunca se usa una configuración insegura.
  final entorno = Entorno.desdeDefinicion();
  // Sin las opciones de Firebase (--dart-define) la App funciona igual, sin avisos push.
  final push = await ProveedorPushFirebase.iniciar();
  runApp(AppConpociiech(entorno: entorno, proveedorPush: push));
}

import 'package:flutter/material.dart';

import 'app.dart';
import 'core/config/entorno.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Falla al arrancar si API_BASE_URL no es https: nunca se usa una configuración insegura.
  runApp(AppConpociiech(entorno: Entorno.desdeDefinicion()));
}

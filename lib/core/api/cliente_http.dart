import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Cliente HTTP de la App. Valida siempre el certificado del servidor; si se indica
/// [caDesarrollo] (solo en debug/profile, ver `Entorno`), confía además en esa CA local
/// para probar contra TEC levantado en la PC. Android no permite que `dart:io` use las CA
/// instaladas por el usuario, por eso la CA se entrega en la compilación de desarrollo.
http.Client crearClienteHttp({String? caDesarrollo}) {
  if (caDesarrollo == null || caDesarrollo.isEmpty) return http.Client();
  final contexto = SecurityContext(withTrustedRoots: true)
    ..setTrustedCertificatesBytes(utf8.encode(pemDesdeDefinicion(caDesarrollo)));
  return IOClient(HttpClient(context: contexto));
}

/// Normaliza la CA recibida por `--dart-define`. Se recomienda una sola línea en base64
/// (el cuerpo del certificado, sin encabezados): en Windows, los espacios y saltos de
/// línea de un PEM dentro de un `--dart-define` rompen la llamada al compilador. También
/// acepta un PEM completo (con saltos reales o «\n» literales).
String pemDesdeDefinicion(String valor) {
  final texto = valor.replaceAll(r'\n', '\n').trim();
  if (texto.contains('-----BEGIN')) return texto;
  final cuerpo = texto.replaceAll(RegExp(r'\s'), '');
  final lineas = [
    for (var i = 0; i < cuerpo.length; i += 64)
      cuerpo.substring(i, i + 64 > cuerpo.length ? cuerpo.length : i + 64),
  ];
  return '-----BEGIN CERTIFICATE-----\n${lineas.join('\n')}\n-----END CERTIFICATE-----\n';
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:app_conpociiech/core/api/cliente_api.dart';
import 'package:app_conpociiech/core/config/entorno.dart';
import 'package:app_conpociiech/core/sesion/almacen_tokens.dart';
import 'package:app_conpociiech/core/sesion/api_autenticacion.dart';
import 'package:app_conpociiech/core/sesion/sesion_controller.dart';

/// Usuario de prueba del servidor simulado (no son credenciales reales).
class UsuarioSimulado {
  UsuarioSimulado({required this.clave, required this.roles, this.permanente = true});

  String clave;
  final List<String> roles;
  bool permanente;
}

/// Simula los endpoints `/auth/*` de TEC con las mismas reglas del contrato: refresh
/// rotativo (reutilizarlo revoca la sesión), sesión restringida al cambio de clave y
/// revocación de todas las sesiones al cambiar la clave.
class TecSimulado {
  final Map<String, UsuarioSimulado> usuarios = {};
  final Map<String, String> _accesos = {}; // access -> usuario
  final Map<String, String> _refresh = {}; // refresh -> usuario
  final Set<String> _refreshUsados = {};
  final Set<String> _restringidos = {}; // access de sesiones solo para cambiar clave
  int _secuencia = 0;
  bool sinConexion = false;
  final List<String> rutas = [];

  /// Invalida los tokens de acceso vigentes (como si hubieran vencido en TEC).
  void vencerAccesos() => _accesos.clear();

  late final http.Client cliente = MockClient(_atender);

  /// Cliente de la App apuntando al servidor simulado.
  late final ClienteApi api = ClienteApi(Entorno.desdeUrl(Entorno.urlPorDefecto).apiBaseUrl, cliente: cliente);

  /// Consultas recibidas con sus parámetros (p. ej. paginación de miembros).
  final List<Uri> consultas = [];

  SesionController crearSesion({AlmacenTokens? almacen, DateTime Function()? reloj}) => SesionController(
        api: ApiAutenticacion(api, reloj: reloj),
        almacen: almacen ?? AlmacenTokensMemoria(),
        reloj: reloj,
      );

  Future<http.Response> _atender(http.Request peticion) async {
    if (sinConexion) throw http.ClientException('sin red');
    final ruta = peticion.url.path.replaceFirst('/api/v1', '');
    rutas.add(ruta);
    final cuerpo = peticion.body.isEmpty ? <String, dynamic>{} : jsonDecode(peticion.body) as Map<String, dynamic>;
    final bearer = peticion.headers['Authorization']?.replaceFirst('Bearer ', '');

    switch (ruta) {
      case '/auth/login':
        final usuario = usuarios[cuerpo['usuario']];
        if (usuario == null || usuario.clave != cuerpo['clave']) {
          return _error(401, 'CREDENCIALES_INVALIDAS', 'Usuario o contraseña incorrectos.');
        }
        return _emitir(cuerpo['usuario'] as String);
      case '/auth/refresh':
        final token = cuerpo['refreshToken'] as String?;
        final nombre = _refresh.remove(token);
        if (nombre == null) {
          if (_refreshUsados.contains(token)) _revocarTodo();
          return _sesionInvalida();
        }
        _refreshUsados.add(token!);
        return _emitir(nombre);
    }

    final nombre = _accesos[bearer];
    if (nombre == null) return _sesionInvalida();
    switch (ruta) {
      case '/auth/yo':
        return _json(200, _perfil(nombre));
      case '/auth/logout':
        _accesos.remove(bearer);
        return http.Response('', 204);
      case '/auth/cambiar-clave':
        final usuario = usuarios[nombre]!;
        if (cuerpo['claveActual'] != usuario.clave) {
          return _error(400, 'CLAVE_INCORRECTA', 'La contraseña actual no es correcta.');
        }
        usuario
          ..clave = cuerpo['claveNueva'] as String
          ..permanente = true;
        _revocarTodo();
        return _emitir(nombre);
    }
    if (_restringidos.contains(bearer)) {
      return _error(403, 'CAMBIO_CLAVE_OBLIGATORIO', 'Debe cambiar su contraseña.');
    }
    consultas.add(peticion.url);
    return _tribunal(ruta, usuarios[nombre]!.roles, peticion.url.queryParameters, peticion.method, cuerpo);
  }

  // ------------------------------------------------------------ Módulo Tribunal

  /// Miembros simulados de la iglesia (más de una página).
  final List<Map<String, dynamic>> miembros = [
    for (var i = 1; i <= 45; i++) {'id': i, 'nombre': 'Miembro ${i.toString().padLeft(2, '0')}', 'habilitado': i.isOdd, 'revisado': i % 3 == 0},
  ];

  /// Estado del escrutinio de la mesa simulada del Presidente.
  String estadoMesa = 'ABIERTO';

  /// El cronograma simulado permite cambiar la habilitación de los miembros.
  bool edicionAbierta = true;

  http.Response _tribunal(
      String ruta, List<String> roles, Map<String, String> parametros, String metodo, Map<String, dynamic> cuerpo) {
    bool permite(Set<String> requeridos) => roles.any(requeridos.contains);
    const presidente = {'SITEC-Presidente-mesa'};
    const iglesia = {'SITEC-IglesiaAdmin'};
    const proceso = {'SITEC-Administrador', 'SITEC-Tribunal'};
    final requeridos = ruta.startsWith('/tribunal/presidente')
        ? presidente
        : ruta.startsWith('/tribunal/iglesia')
            ? iglesia
            : ruta.startsWith('/tribunal/proceso')
                ? proceso
                : null;
    if (requeridos == null) return _error(404, 'RECURSO_NO_ENCONTRADO', 'La solicitud no es válida.');
    if (!permite(requeridos)) return _error(403, 'SIN_PERMISO', 'No tiene permiso para esta operación.');

    final habilitacion = RegExp(r'^/tribunal/iglesia/miembros/(\d+)/habilitacion$').firstMatch(ruta);
    if (habilitacion != null && metodo == 'PUT') {
      if (!edicionAbierta) {
        return _error(409, 'EDICION_CERRADA', 'La actualización del padrón está cerrada por el cronograma electoral.');
      }
      final id = int.parse(habilitacion.group(1)!);
      final i = miembros.indexWhere((m) => m['id'] == id);
      if (i < 0) return _error(404, 'MIEMBRO_NO_DISPONIBLE', 'El miembro no existe o ya no está activo en la iglesia.');
      if (cuerpo['habilitado'] is! bool) return _error(400, 'SOLICITUD_INVALIDA', 'Indique si el miembro queda habilitado.');
      miembros[i] = {...miembros[i], 'habilitado': cuerpo['habilitado'], 'revisado': true};
      return _json(200, miembros[i]);
    }

    const ubicacion = {'mesaId': 7, 'mesa': 'MESA 7', 'recinto': 'Escuela Central', 'parroquia': 'Matriz', 'canton': 'Riobamba'};
    switch (ruta) {
      case '/tribunal/presidente/mesa':
        return _json(200, {
          'proceso': {'id': 1, 'nombre': 'Elecciones 2026', 'faseVigente': 'Sufragio'},
          'ubicacion': ubicacion,
          'estado': estadoMesa,
          'fechaApertura': '2026-10-08T08:00:00Z',
          'electores': 3,
          'junta': [
            {'cargo': 'PRESIDENTE', 'nombre': 'Pérez Ana'},
            {'cargo': 'SECRETARIO', 'nombre': 'Gómez Luis'},
          ],
          'resultados': estadoMesa == 'CERRADO'
              ? {
                  'sufragantes': 3,
                  'votosRegistrados': 3,
                  'votosValidos': 2,
                  'votosBlancos': 1,
                  'votosNulos': 0,
                  'categorias': [
                    {'categoria': 'LISTA 1', 'tipo': 'LISTA', 'votos': 2},
                  ],
                }
              : null,
        });
      case '/tribunal/presidente/padron':
        return _json(200, [
          {'nombre': 'Andrade Rosa', 'iglesia': 'Iglesia Central', 'sufrago': true},
          {'nombre': 'Bravo Juan', 'iglesia': 'Iglesia Norte', 'sufrago': false},
          {'nombre': 'Cruz María', 'iglesia': 'Iglesia Central', 'sufrago': null},
        ]);
      case '/tribunal/iglesia':
        return _json(200, {
          'id': 3,
          'nombre': 'Iglesia Central',
          'comunidad': 'San Juan',
          'parroquia': 'Matriz',
          'canton': 'Riobamba',
          'provincia': 'Chimborazo',
          'totalMiembros': 45,
          'miembrosHabilitados': 23,
          'miembrosNoHabilitados': 22,
          'informacionCompleta': 40,
          'pendientesRevision': 5,
          'enOtraIglesia': 1,
          'permiteEdicion': edicionAbierta,
        });
      case '/tribunal/iglesia/miembros':
        final busqueda = parametros['busqueda']?.toLowerCase();
        final habilitado = parametros['habilitado'] == null ? null : parametros['habilitado'] == 'true';
        final filtrados = miembros
            .where((m) =>
                (busqueda == null || (m['nombre'] as String).toLowerCase().contains(busqueda)) &&
                (habilitado == null || m['habilitado'] == habilitado))
            .toList();
        final pagina = int.parse(parametros['pagina'] ?? '0');
        final tamano = int.parse(parametros['tamano'] ?? '30');
        return _json(200, {
          'total': filtrados.length,
          'pagina': pagina,
          'tamano': tamano,
          'elementos': filtrados.skip(pagina * tamano).take(tamano).toList(),
        });
      case '/tribunal/proceso/resumen':
        return _json(200, {
          'proceso': {'id': 1, 'nombre': 'Elecciones 2026', 'faseVigente': 'Sufragio'},
          'iglesias': 120,
          'recintos': 10,
          'mesas': 2,
          'electores': 1500,
          'mesasConJuntaCompleta': 2,
          'mesasCerradas': 1,
          'porcentajeEscrutinio': 50,
          'mesasPorEstado': {'CERRADO': 1, 'ABIERTO': 1},
        });
      case '/tribunal/proceso/mesas':
        return _json(200, [
          {'ubicacion': ubicacion, 'estado': 'ABIERTO', 'juntaRegistrada': true},
          {
            'ubicacion': {'mesaId': 8, 'mesa': 'MESA 8', 'recinto': 'Colegio Norte', 'parroquia': 'Lizarzaburu', 'canton': 'Guano'},
            'estado': 'CERRADO',
            'juntaRegistrada': true,
          },
        ]);
      case '/tribunal/proceso/resultados':
        return _json(200, {
          'proceso': 'Elecciones 2026',
          'mesas': 2,
          'mesasCerradas': 1,
          'porcentajeMesasCerradas': 50,
          'votosRegistrados': 300,
          'votosBlancos': 10,
          'votosNulos': 5,
          'categorias': [
            {'categoria': 'LISTA 1', 'tipo': 'LISTA', 'lista': 'Lista 1 Unidad', 'votos': 200, 'porcentaje': 69.57},
            {'categoria': 'LISTA 2', 'tipo': 'LISTA', 'lista': 'Lista 2 Renovación', 'votos': 85, 'porcentaje': 30.43},
          ],
          'actualizado': '2026-10-08T18:30:00Z',
        });
    }
    return _error(404, 'RECURSO_NO_ENCONTRADO', 'La solicitud no es válida.');
  }

  http.Response _emitir(String nombre) {
    final usuario = usuarios[nombre]!;
    final acceso = 'acceso-${++_secuencia}';
    final refresh = 'refresh-$_secuencia';
    _accesos[acceso] = nombre;
    _refresh[refresh] = nombre;
    if (!usuario.permanente) _restringidos.add(acceso);
    return _json(200, {
      'accessToken': acceso,
      'refreshToken': refresh,
      'tipo': 'Bearer',
      'expiraEnSegundos': 300,
      'cambioClaveObligatorio': !usuario.permanente,
      'usuario': _perfil(nombre),
    });
  }

  Map<String, dynamic> _perfil(String nombre) => {
        'usuario': nombre,
        'nombre': 'Persona $nombre',
        'roles': usuarios[nombre]!.roles,
        'iglesiaId': null,
        'cambioClaveObligatorio': !usuarios[nombre]!.permanente,
      };

  void _revocarTodo() {
    _accesos.clear();
    _refresh.clear();
  }

  static http.Response _sesionInvalida() =>
      _error(401, 'SESION_INVALIDA', 'La sesión no es válida o expiró. Inicie sesión nuevamente.');

  static http.Response _error(int estado, String codigo, String mensaje) =>
      _json(estado, {'codigo': codigo, 'mensaje': mensaje});

  static http.Response _json(int estado, Object cuerpo) => http.Response.bytes(
        utf8.encode(jsonEncode(cuerpo)),
        estado,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
}

/// Error esperado de una petición.
Matcher errorApi(String codigo) => isA<ErrorApi>().having((e) => e.codigo, 'codigo', codigo);

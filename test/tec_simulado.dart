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
  UsuarioSimulado({
    required this.clave,
    required this.roles,
    this.permanente = true,
  });

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
  final Set<String> _restringidos =
      {}; // access de sesiones solo para cambiar clave
  int _secuencia = 0;
  bool sinConexion = false;
  final List<String> rutas = [];

  /// Invalida los tokens de acceso vigentes (como si hubieran vencido en TEC).
  void vencerAccesos() => _accesos.clear();

  late final http.Client cliente = MockClient(_atender);

  /// Cliente de la App apuntando al servidor simulado.
  late final ClienteApi api = ClienteApi(
    Entorno.desdeUrl(Entorno.urlPorDefecto).apiBaseUrl,
    cliente: cliente,
  );

  /// Tokens de avisos push registrados (token → usuario).
  final Map<String, String> dispositivos = {};

  /// Consultas recibidas con sus parámetros (p. ej. paginación de miembros).
  final List<Uri> consultas = [];

  /// Cuerpos JSON recibidos por el módulo Tribunal (para comprobar qué campos se envían).
  final List<Map<String, dynamic>> cuerpos = [];

  SesionController crearSesion({
    AlmacenTokens? almacen,
    DateTime Function()? reloj,
  }) => SesionController(
    api: ApiAutenticacion(api, reloj: reloj),
    almacen: almacen ?? AlmacenTokensMemoria(),
    reloj: reloj,
  );

  Future<http.Response> _atender(http.Request peticion) async {
    if (sinConexion) throw http.ClientException('sin red');
    final ruta = peticion.url.path.replaceFirst('/api/v1', '');
    rutas.add(ruta);
    final esJson =
        peticion.headers['Content-Type']?.startsWith('application/json') ??
        false;
    final cuerpo = !esJson || peticion.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(peticion.body) as Map<String, dynamic>;
    ultimoBinario = esJson ? null : peticion.bodyBytes;
    ultimoTipo = peticion.headers['Content-Type'];
    final bearer = peticion.headers['Authorization']?.replaceFirst(
      'Bearer ',
      '',
    );

    switch (ruta) {
      case '/auth/login':
        final usuario = usuarios[cuerpo['usuario']];
        if (usuario == null || usuario.clave != cuerpo['clave']) {
          return _error(
            401,
            'CREDENCIALES_INVALIDAS',
            'Usuario o contraseña incorrectos.',
          );
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
          return _error(
            400,
            'CLAVE_INCORRECTA',
            'La contraseña actual no es correcta.',
          );
        }
        usuario
          ..clave = cuerpo['claveNueva'] as String
          ..permanente = true;
        _revocarTodo();
        return _emitir(nombre);
    }
    if (_restringidos.contains(bearer)) {
      return _error(
        403,
        'CAMBIO_CLAVE_OBLIGATORIO',
        'Debe cambiar su contraseña.',
      );
    }
    if (ruta == '/dispositivos' && peticion.method == 'POST') {
      dispositivos[cuerpo['token'] as String] = nombre;
      return http.Response('', 204);
    }
    if (ruta == '/dispositivos/baja' && peticion.method == 'POST') {
      if (dispositivos[cuerpo['token']] == nombre)
        dispositivos.remove(cuerpo['token']);
      return http.Response('', 204);
    }
    consultas.add(peticion.url);
    if (esJson) cuerpos.add(cuerpo);
    return _tribunal(
      ruta,
      usuarios[nombre]!.roles,
      peticion.url.queryParameters,
      peticion.method,
      cuerpo,
    );
  }

  // ------------------------------------------------------------ Módulo Tribunal

  /// Miembros simulados de la iglesia (más de una página).
  final List<Map<String, dynamic>> miembros = [
    for (var i = 1; i <= 45; i++)
      {
        'id': i,
        'nombre': 'Miembro ${i.toString().padLeft(2, '0')}',
        'habilitado': i.isOdd,
        'revisado': i % 3 == 0,
        // Valor almacenado: M, F o sin dato.
        'sexo': i % 5 == 0 ? null : (i.isEven ? 'F' : 'M'),
      },
  ];

  /// Estado del escrutinio de la mesa simulada del Presidente.
  String estadoMesa = 'ABIERTO';

  /// El cronograma simulado permite cambiar la habilitación de los miembros.
  bool edicionAbierta = true;

  /// Datos de la persona por id de miembro (se crean al consultarlos).
  final Map<int, Map<String, dynamic>> personas = {};

  /// Guardados de datos de persona que llegaron a TEC (sin cambios no debe haber).
  int actualizacionesPersona = 0;

  /// Cambios de solo habilitación (TEC usa cambiarHabilitacion, sin tocar Persona).
  int soloHabilitaciones = 0;

  /// Id de un miembro de otra iglesia: TEC responde 403 aunque la App conozca el id.
  static const int miembroDeOtraIglesia = 999;

  /// Cédula con formato válido pero dígito verificador incorrecto (lo valida TEC).
  static const String cedulaInvalida = '1710034066';

  /// Cédula válida que ya pertenece a otra persona.
  static const String cedulaDeOtraPersona = '1710034057';

  // Escrutinio simulado (mismas transiciones que EscrutinioService).
  String estadoActa = 'PENDIENTE';
  String? bloqueoApertura;
  final Map<int, int> votosActa = {};
  Map<String, dynamic>? actaFisica;
  List<int>? ultimoBinario;
  String? ultimoTipo;
  static const List<(int, String, bool)> categoriasActa = [
    (1, 'LISTA 1', false),
    (2, 'BLANCOS', false),
    (3, 'PAPELETAS NO UTILIZADAS', true),
  ];
  static const int sufragantesActa = 10;

  // Revisión del acta física de la mesa 8 (cerrada, con foto pendiente de revisión).
  String revisionMesa8 = 'PENDIENTE_REVISION';
  String estadoMesa8 = 'CERRADO';
  String? observacionMesa8;

  http.Response _revision(
    int mesaId,
    String? actaFisica,
    String? accion,
    String metodo,
    Map<String, dynamic> cuerpo,
    List<String> roles,
  ) {
    // Decidir la revisión es solo del Tribunal; el Administrador consulta.
    final tribunal = roles.contains('SITEC-Tribunal');
    if (mesaId != 8)
      return _error(
        404,
        'MESA_NO_ENCONTRADA',
        'La mesa no existe en el proceso electoral activo.',
      );
    Map<String, dynamic> detalle() => {
      'ubicacion': {
        'mesaId': 8,
        'mesa': 'MESA 8',
        'recinto': 'Colegio Norte',
        'parroquia': 'Lizarzaburu',
        'canton': 'Guano',
      },
      'estado': estadoMesa8,
      'electores': 10,
      'junta': [
        {'cargo': 'PRESIDENTE', 'nombre': 'Ortiz Carla'},
      ],
      'conteo': [
        {'categoria': 'LISTA 1', 'tipo': 'LISTA', 'votos': 6},
        {'categoria': 'BLANCOS', 'tipo': null, 'votos': 2},
      ],
      'cuadre': 0,
      'actaFisica': {
        'version': 1,
        'estadoRevision': revisionMesa8,
        'observacion': observacionMesa8,
      },
      'puedeRevisarActa':
          tribunal && estadoMesa8 == 'CERRADO' && revisionMesa8 != 'VALIDADA',
    };
    if (actaFisica == null && metodo == 'GET') return _json(200, detalle());
    if (accion == null && metodo == 'GET') {
      return http.Response.bytes(
        [0xFF, 0xD8, 0xFF, 0xE0],
        200,
        headers: {'content-type': 'image/jpeg'},
      );
    }
    if (metodo != 'POST')
      return _error(404, 'RECURSO_NO_ENCONTRADO', 'La solicitud no es válida.');
    if (!tribunal)
      return _error(
        403,
        'SIN_PERMISO',
        'No tiene permiso para esta operación.',
      );
    if (estadoMesa8 != 'CERRADO' || revisionMesa8 == 'VALIDADA') {
      return _error(
        409,
        'REGLA_REVISION',
        'La mesa debe estar cerrada para revisar su acta física.',
      );
    }
    if (accion == '/validacion') {
      if (cuerpo['cotejoConfirmado'] != true) {
        return _error(
          400,
          'COTEJO_REQUERIDO',
          'Confirme que el acta física coincide con lo registrado.',
        );
      }
      revisionMesa8 = 'VALIDADA';
    } else {
      final motivo = (cuerpo['motivo'] as String? ?? '').trim();
      if (motivo.isEmpty)
        return _error(
          409,
          'REGLA_REVISION',
          'Indique el motivo de la devolución del acta.',
        );
      revisionMesa8 = cuerpo['estado'] as String;
      observacionMesa8 = motivo;
      estadoMesa8 = 'REABIERTO';
    }
    return _json(200, detalle());
  }

  Map<String, dynamic> _acta() {
    var emitidos = 0;
    var papeletas = 0;
    for (final (id, _, esPapeletas) in categoriasActa) {
      if (esPapeletas) {
        papeletas += votosActa[id] ?? 0;
      } else {
        emitidos += votosActa[id] ?? 0;
      }
    }
    const editables = {
      'ABIERTO',
      'EN_CONTEO',
      'CONTEO_REGISTRADO',
      'REABIERTO',
    };
    return {
      'ubicacion': {
        'mesaId': 7,
        'mesa': 'MESA 7',
        'recinto': 'Escuela Central',
      },
      'estado': estadoActa,
      'sufragantes': sufragantesActa,
      'votosEmitidos': emitidos,
      'papeletasNoUtilizadas': papeletas,
      'cuadre': sufragantesActa - emitidos - papeletas,
      'motivoBloqueoApertura': estadoActa == 'PENDIENTE'
          ? bloqueoApertura
          : null,
      'puedeAbrir': estadoActa == 'PENDIENTE' && bloqueoApertura == null,
      'puedeEditarConteo': editables.contains(estadoActa),
      'puedeCerrar': editables.contains(estadoActa) && estadoActa != 'ABIERTO',
      'puedeSubirActaFisica':
          estadoActa == 'CERRADO' &&
          actaFisica?['estadoRevision'] != 'VALIDADA',
      'categorias': [
        for (final (id, nombre, esPapeletas) in categoriasActa)
          {
            'categoriaId': id,
            'nombre': nombre,
            'papeletas': esPapeletas,
            'votos': votosActa[id] ?? 0,
          },
      ],
      'actaFisica': actaFisica,
    };
  }

  http.Response _escrutinio(
    String ruta,
    String metodo,
    Map<String, dynamic> cuerpo,
  ) {
    http.Response regla(String mensaje) =>
        _error(409, 'REGLA_ESCRUTINIO', mensaje);
    Map<int, int>? votos() {
      final lista = cuerpo['votos'] as List<dynamic>? ?? const [];
      final m = {
        for (final v in lista)
          (v as Map<String, dynamic>)['categoriaId'] as int: v['votos'] as int,
      };
      return m.length == categoriasActa.length ? m : null;
    }

    switch ((metodo, ruta)) {
      case ('GET', '/tribunal/presidente/acta'):
        return _json(200, _acta());
      case ('POST', '/tribunal/presidente/acta/apertura'):
        if (estadoActa != 'PENDIENTE')
          return regla('La apertura de la mesa ya fue registrada.');
        if (bloqueoApertura != null) return regla(bloqueoApertura!);
        estadoActa = 'ABIERTO';
        return _json(200, _acta());
      case ('PUT', '/tribunal/presidente/acta/conteo'):
        if (estadoActa == 'PENDIENTE')
          return regla(
            'Debe registrar la apertura de la mesa antes de guardar el conteo.',
          );
        if (estadoActa == 'CERRADO')
          return regla('El escrutinio ya se encuentra cerrado.');
        final v = votos();
        if (v == null)
          return _error(
            400,
            'SOLICITUD_INVALIDA',
            'Registre los votos de cada categoría una sola vez.',
          );
        votosActa
          ..clear()
          ..addAll(v);
        estadoActa = _acta()['cuadre'] == 0 ? 'CONTEO_REGISTRADO' : 'EN_CONTEO';
        return _json(200, _acta());
      case ('POST', '/tribunal/presidente/acta/cierre'):
        if (!{
          'EN_CONTEO',
          'CONTEO_REGISTRADO',
          'REABIERTO',
        }.contains(estadoActa)) {
          return regla('Debe guardar el conteo antes de cerrar la mesa.');
        }
        final v = votos();
        if (v == null)
          return _error(
            400,
            'SOLICITUD_INVALIDA',
            'Registre los votos de cada categoría una sola vez.',
          );
        votosActa
          ..clear()
          ..addAll(v);
        estadoActa = 'CERRADO';
        return _json(200, _acta());
      case ('PUT', '/tribunal/presidente/acta/acta-fisica'):
        if (estadoActa != 'CERRADO')
          return regla(
            'La mesa debe estar cerrada para cargar el acta física.',
          );
        actaFisica = {
          'version': (actaFisica?['version'] as int? ?? 0) + 1,
          'estadoRevision': 'PENDIENTE_REVISION',
        };
        return _json(200, _acta());
    }
    return _error(404, 'RECURSO_NO_ENCONTRADO', 'La solicitud no es válida.');
  }

  http.Response _tribunal(
    String ruta,
    List<String> roles,
    Map<String, String> parametros,
    String metodo,
    Map<String, dynamic> cuerpo,
  ) {
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
    if (requeridos == null)
      return _error(404, 'RECURSO_NO_ENCONTRADO', 'La solicitud no es válida.');
    if (!permite(requeridos))
      return _error(
        403,
        'SIN_PERMISO',
        'No tiene permiso para esta operación.',
      );

    if (ruta.startsWith('/tribunal/presidente/acta'))
      return _escrutinio(ruta, metodo, cuerpo);

    final mesa = RegExp(
      r'^/tribunal/proceso/mesas/(\d+)(/acta-fisica(/validacion|/devolucion)?)?$',
    ).firstMatch(ruta);
    if (mesa != null)
      return _revision(
        int.parse(mesa.group(1)!),
        mesa.group(2),
        mesa.group(3),
        metodo,
        cuerpo,
        roles,
      );

    final habilitacion = RegExp(
      r'^/tribunal/iglesia/miembros/(\d+)/habilitacion$',
    ).firstMatch(ruta);
    if (habilitacion != null && metodo == 'PUT') {
      if (!edicionAbierta) {
        return _error(
          409,
          'EDICION_CERRADA',
          'La actualización del padrón está cerrada por el cronograma electoral.',
        );
      }
      final id = int.parse(habilitacion.group(1)!);
      final i = miembros.indexWhere((m) => m['id'] == id);
      if (i < 0)
        return _error(
          404,
          'MIEMBRO_NO_DISPONIBLE',
          'El miembro no existe o ya no está activo en la iglesia.',
        );
      if (cuerpo['habilitado'] is! bool)
        return _error(
          400,
          'SOLICITUD_INVALIDA',
          'Indique si el miembro queda habilitado.',
        );
      miembros[i] = {
        ...miembros[i],
        'habilitado': cuerpo['habilitado'],
        'revisado': true,
      };
      return _json(200, miembros[i]);
    }

    // Edición de la persona (GestionMovilService.actualizarPersonaMiembro).
    final persona = RegExp(
      r'^/tribunal/iglesia/miembros/(\d+)(/persona)?$',
    ).firstMatch(ruta);
    if (persona != null) {
      final id = int.parse(persona.group(1)!);
      if (id == miembroDeOtraIglesia) {
        return _error(403, 'SIN_PERMISO', 'No puede gestionar miembros de otra iglesia.');
      }
      final i = miembros.indexWhere((m) => m['id'] == id);
      if (i < 0) {
        return _error(404, 'MIEMBRO_NO_DISPONIBLE', 'El miembro no existe o ya no está activo en la iglesia.');
      }
      final datos = personas.putIfAbsent(
        id,
        () => {'nombres': miembros[i]['nombre'], 'documento': '1710034065', 'sexo': miembros[i]['sexo']},
      );
      Map<String, dynamic> detalle() => {
        'id': id,
        'nombre': datos['nombres'],
        ...datos,
        'habilitado': miembros[i]['habilitado'],
        'revisado': miembros[i]['revisado'],
        'permiteEdicion': edicionAbierta,
      };
      if (persona.group(2) == null && metodo == 'GET') return _json(200, detalle());
      if (persona.group(2) != null && metodo == 'PUT') {
        if (!edicionAbierta) {
          return _error(409, 'EDICION_CERRADA', 'La actualización del padrón está cerrada por el cronograma electoral.');
        }
        final nombres = (cuerpo['nombres'] as String? ?? '').trim();
        final documento = (cuerpo['documento'] as String? ?? '').trim();
        if (nombres.isEmpty) {
          return _error(400, 'DATOS_INVALIDOS', 'Los nombres de la persona son obligatorios.');
        }
        if (!RegExp(r'^\d{10}$').hasMatch(documento) || documento == cedulaInvalida) {
          return _error(400, 'DATOS_INVALIDOS', 'La cédula ingresada no es válida.');
        }
        if (documento == cedulaDeOtraPersona) {
          return _error(409, 'DOCUMENTO_DUPLICADO', 'La cédula ingresada ya pertenece a otra persona.');
        }
        // Igual que GestionMovilService: datos de la persona (con o sin habilitación) →
        // guardarDesdeDTO; solo habilitación → cambiarHabilitacion; nada → sin guardar.
        final cambiaPersona = nombres != datos['nombres'] ||
            documento != datos['documento'] ||
            cuerpo['sexo'] != datos['sexo'];
        final habilitado = cuerpo['habilitado'] as bool?;
        final cambiaHabilitacion = habilitado != null && habilitado != miembros[i]['habilitado'];
        if (cambiaPersona) {
          actualizacionesPersona++;
          datos
            ..['nombres'] = nombres
            ..['documento'] = documento
            ..['sexo'] = cuerpo['sexo'];
        } else if (cambiaHabilitacion) {
          soloHabilitaciones++;
        }
        if (cambiaPersona || cambiaHabilitacion) {
          miembros[i] = {
            ...miembros[i],
            'nombre': datos['nombres'],
            'sexo': datos['sexo'],
            if (cambiaHabilitacion) 'habilitado': habilitado,
            'revisado': true,
          };
        }
        return _json(200, detalle());
      }
    }

    const ubicacion = {
      'mesaId': 7,
      'mesa': 'MESA 7',
      'recinto': 'Escuela Central',
      'parroquia': 'Matriz',
      'canton': 'Riobamba',
    };
    switch (ruta) {
      case '/tribunal/presidente/mesa':
        return _json(200, {
          'proceso': {
            'id': 1,
            'nombre': 'Elecciones 2026',
            'faseVigente': 'Sufragio',
          },
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
          {
            'nombre': 'Andrade Rosa',
            'iglesia': 'Iglesia Central',
            'sufrago': true,
          },
          {
            'nombre': 'Bravo Juan',
            'iglesia': 'Iglesia Norte',
            'sufrago': false,
          },
          {
            'nombre': 'Cruz María',
            'iglesia': 'Iglesia Central',
            'sufrago': null,
          },
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
          'pendientesRevision': miembros
              .where((m) => m['revisado'] != true)
              .length,
          'enOtraIglesia': 1,
          'permiteEdicion': edicionAbierta,
        });
      case '/tribunal/iglesia/miembros':
        final busqueda = parametros['busqueda']?.toLowerCase();
        final habilitado = parametros['habilitado'] == null
            ? null
            : parametros['habilitado'] == 'true';
        final revisado = parametros['revisado'] == null
            ? null
            : parametros['revisado'] == 'true';
        final filtrados = miembros
            .where(
              (m) =>
                  (busqueda == null ||
                      (m['nombre'] as String).toLowerCase().contains(
                        busqueda,
                      )) &&
                  (habilitado == null || m['habilitado'] == habilitado) &&
                  (revisado == null || (m['revisado'] == true) == revisado),
            )
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
          'proceso': {
            'id': 1,
            'nombre': 'Elecciones 2026',
            'faseVigente': 'Sufragio',
          },
          'iglesias': 120,
          'recintos': 10,
          'mesas': 2,
          'electores': 1500,
          'mesasConJuntaCompleta': 2,
          'mesasCerradas': 1,
          'porcentajeEscrutinio': 50,
          'mesasPorEstado': {'CERRADO': 1, 'ABIERTO': 1},
          'alertas': [
            {
              'texto': 'Mesas con escrutinio observado',
              'cantidad': 1,
              'severidad': 'danger',
            },
            {
              'texto': 'Mesas cerradas sin acta física cargada',
              'cantidad': 2,
              'severidad': 'warn',
            },
          ],
        });
      case '/tribunal/proceso/mesas':
        return _json(200, [
          {
            'ubicacion': ubicacion,
            'estado': 'ABIERTO',
            'juntaRegistrada': true,
          },
          {
            'ubicacion': {
              'mesaId': 8,
              'mesa': 'MESA 8',
              'recinto': 'Colegio Norte',
              'parroquia': 'Lizarzaburu',
              'canton': 'Guano',
            },
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
            {
              'categoria': 'LISTA 1',
              'tipo': 'LISTA',
              'lista': 'Lista 1 Unidad',
              'votos': 200,
              'porcentaje': 69.57,
            },
            {
              'categoria': 'LISTA 2',
              'tipo': 'LISTA',
              'lista': 'Lista 2 Renovación',
              'votos': 85,
              'porcentaje': 30.43,
            },
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

  static http.Response _sesionInvalida() => _error(
    401,
    'SESION_INVALIDA',
    'La sesión no es válida o expiró. Inicie sesión nuevamente.',
  );

  static http.Response _error(int estado, String codigo, String mensaje) =>
      _json(estado, {'codigo': codigo, 'mensaje': mensaje});

  static http.Response _json(int estado, Object cuerpo) => http.Response.bytes(
    utf8.encode(jsonEncode(cuerpo)),
    estado,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

/// Error esperado de una petición.
Matcher errorApi(String codigo) =>
    isA<ErrorApi>().having((e) => e.codigo, 'codigo', codigo);

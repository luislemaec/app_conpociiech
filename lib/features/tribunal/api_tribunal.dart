import '../../core/api/cliente_api.dart';
import '../../core/sesion/sesion_controller.dart';

/// Consultas de solo lectura del módulo Tribunal (`/tribunal/*` de TEC). TEC autoriza
/// cada una por rol y resuelve el alcance (mesa, iglesia, proceso activo) desde el usuario.
class ApiTribunal {
  ApiTribunal(this._cliente, this._sesion);

  final ClienteApi _cliente;
  final SesionController _sesion;

  Future<Map<String, dynamic>?> _get(String ruta) => _sesion.autenticada(
    (token) => _cliente.enviar('GET', ruta, token: token),
  );

  Future<List<dynamic>> _lista(String ruta) => _sesion.autenticada(
    (token) => _cliente.enviarLista('GET', ruta, token: token),
  );

  Future<MesaPresidente> mesaPresidente() async =>
      MesaPresidente.desdeJson((await _get('/tribunal/presidente/mesa'))!);

  Future<List<Elector>> padronPresidente() async => (await _lista(
    '/tribunal/presidente/padron',
  )).map((e) => Elector.desdeJson(e as Map<String, dynamic>)).toList();

  Future<IglesiaResumen> iglesia() async =>
      IglesiaResumen.desdeJson((await _get('/tribunal/iglesia'))!);

  Future<PaginaMiembros> miembros({
    String? busqueda,
    bool? habilitado,
    bool? revisado,
    int pagina = 0,
    int tamano = 30,
  }) async {
    final consulta = Uri(
      queryParameters: {
        if (busqueda != null && busqueda.trim().isNotEmpty)
          'busqueda': busqueda.trim(),
        if (habilitado != null) 'habilitado': '$habilitado',
        // revisado = false: pendientes de revisión.
        if (revisado != null) 'revisado': '$revisado',
        'pagina': '$pagina',
        'tamano': '$tamano',
      },
    ).query;
    return PaginaMiembros.desdeJson(
      (await _get('/tribunal/iglesia/miembros?$consulta'))!,
    );
  }

  /// Habilita o deshabilita a un miembro para participar en las elecciones. TEC valida el
  /// cronograma y que el miembro sea de la iglesia del usuario, y lo marca como revisado.
  Future<Miembro> cambiarHabilitacion(int miembroId, bool habilitado) async {
    final json = await _sesion.autenticada(
      (token) => _cliente.enviar(
        'PUT',
        '/tribunal/iglesia/miembros/$miembroId/habilitacion',
        token: token,
        cuerpo: {'habilitado': habilitado},
      ),
    );
    return Miembro.desdeJson(json!);
  }

  /// Datos actuales y editables de la persona de un miembro de la iglesia del usuario.
  Future<MiembroDetalle> detalleMiembro(int miembroId) async =>
      MiembroDetalle.desdeJson(
        (await _get('/tribunal/iglesia/miembros/$miembroId'))!,
      );

  /// Guarda «Datos de la persona»: «Apellidos y Nombres», cédula, sexo y, si se indica,
  /// la habilitación para el padrón (null = sin cambio). TEC valida
  /// el alcance, el cronograma, la cédula y la iglesia activa con las reglas de la web.
  Future<MiembroDetalle> actualizarPersona(
    int miembroId, {
    required String nombres,
    required String documento,
    String? sexo,
    bool? habilitado,
  }) async {
    final json = await _sesion.autenticada(
      (token) => _cliente.enviar(
        'PUT',
        '/tribunal/iglesia/miembros/$miembroId/persona',
        token: token,
        cuerpo: {
          'nombres': nombres,
          'documento': documento,
          'sexo': sexo,
          'habilitado': ?habilitado,
        },
      ),
    );
    return MiembroDetalle.desdeJson(json!);
  }

  // ---------------------------------------------------------------- Escrutinio del Presidente

  static const String _acta = '/tribunal/presidente/acta';

  Future<ActaPresidente> acta() async =>
      ActaPresidente.desdeJson((await _get(_acta))!);

  Future<ActaPresidente> abrirMesa(String? observacion) =>
      _escribir('POST', '$_acta/apertura', {
        if (observacion != null && observacion.trim().isNotEmpty)
          'observacion': observacion.trim(),
      });

  /// Guarda el conteo como borrador. [votos] debe traer todas las categorías del acta.
  Future<ActaPresidente> guardarConteo(Map<int, int> votos) =>
      _escribir('PUT', '$_acta/conteo', _conteo(votos));

  /// Cierra la mesa con el conteo ya guardado. Después no se puede modificar.
  Future<ActaPresidente> cerrarMesa(Map<int, int> votos) =>
      _escribir('POST', '$_acta/cierre', _conteo(votos));

  /// Sube la foto (JPEG) del acta física firmada de la mesa cerrada.
  Future<ActaPresidente> subirActaFisica(List<int> jpeg) async {
    final json = await _sesion.autenticada(
      (token) => _cliente.enviarArchivo(
        'PUT',
        '$_acta/acta-fisica',
        jpeg,
        tipo: 'image/jpeg',
        token: token,
      ),
    );
    return ActaPresidente.desdeJson(json!);
  }

  Future<ActaPresidente> _escribir(
    String metodo,
    String ruta,
    Object cuerpo,
  ) async {
    final json = await _sesion.autenticada(
      (token) => _cliente.enviar(metodo, ruta, token: token, cuerpo: cuerpo),
    );
    return ActaPresidente.desdeJson(json!);
  }

  static Map<String, Object> _conteo(Map<int, int> votos) => {
    'votos': [
      for (final v in votos.entries) {'categoriaId': v.key, 'votos': v.value},
    ],
  };

  Future<ResumenProceso> resumenProceso() async =>
      ResumenProceso.desdeJson((await _get('/tribunal/proceso/resumen'))!);

  // ---------------------------------------------------------------- Revisión (Administrador, Tribunal)

  Future<DetalleMesa> detalleMesa(int mesaId) async =>
      DetalleMesa.desdeJson((await _get('/tribunal/proceso/mesas/$mesaId'))!);

  /// Foto del acta física vigente (JPEG). TEC registra la consulta en la bitácora.
  Future<List<int>> fotoActa(int mesaId) => _sesion.autenticada(
    (token) => _cliente.obtenerArchivo(
      '/tribunal/proceso/mesas/$mesaId/acta-fisica',
      token: token,
    ),
  );

  /// Marca como datos oficiales lo registrado, tras confirmar el cotejo con el acta física.
  Future<DetalleMesa> validarActa(int mesaId) => _revisarActa(
    '/tribunal/proceso/mesas/$mesaId/acta-fisica/validacion',
    {'cotejoConfirmado': true},
  );

  /// Observa o rechaza el acta con un motivo; la mesa vuelve al Presidente.
  Future<DetalleMesa> devolverActa(
    int mesaId, {
    required bool rechazar,
    required String motivo,
  }) => _revisarActa('/tribunal/proceso/mesas/$mesaId/acta-fisica/devolucion', {
    'estado': rechazar ? 'RECHAZADA' : 'OBSERVADA',
    'motivo': motivo.trim(),
  });

  Future<DetalleMesa> _revisarActa(
    String ruta,
    Map<String, Object> cuerpo,
  ) async {
    final json = await _sesion.autenticada(
      (token) => _cliente.enviar('POST', ruta, token: token, cuerpo: cuerpo),
    );
    return DetalleMesa.desdeJson(json!);
  }

  Future<List<AvanceMesa>> avanceMesas() async => (await _lista(
    '/tribunal/proceso/mesas',
  )).map((e) => AvanceMesa.desdeJson(e as Map<String, dynamic>)).toList();

  Future<ResultadosProceso> resultadosProceso() async =>
      ResultadosProceso.desdeJson(
        (await _get('/tribunal/proceso/resultados'))!,
      );
}

/// Estados del escrutinio de TEC (`EstadoEscrutinio`) con su texto para el usuario.
abstract final class EstadoMesa {
  static const Map<String, String> etiquetas = {
    'PENDIENTE': 'Por abrir',
    'ABIERTO': 'Abierta',
    'EN_CONTEO': 'En conteo',
    'CONTEO_REGISTRADO': 'Conteo registrado',
    'OBSERVADO': 'Observada',
    'CERRADO': 'Cerrada',
    'ANULADO': 'Anulada',
    'REABIERTO': 'Reabierta',
  };

  static String etiqueta(String? estado) =>
      etiquetas[estado] ?? estado ?? 'Sin estado';
}

DateTime? _fecha(Object? valor) {
  if (valor is String) return DateTime.tryParse(valor)?.toLocal();
  if (valor is num) return DateTime.fromMillisecondsSinceEpoch(valor.toInt());
  return null;
}

int _entero(Object? valor) => (valor as num?)?.toInt() ?? 0;

class Proceso {
  const Proceso({required this.nombre, this.faseVigente});

  factory Proceso.desdeJson(Map<String, dynamic> j) => Proceso(
    nombre: j['nombre'] as String? ?? '',
    faseVigente: j['faseVigente'] as String?,
  );

  final String nombre;
  final String? faseVigente;
}

class Ubicacion {
  const Ubicacion({
    this.mesaId,
    required this.mesa,
    this.recinto,
    this.parroquia,
    this.canton,
  });

  factory Ubicacion.desdeJson(Map<String, dynamic> j) => Ubicacion(
    mesaId: (j['mesaId'] as num?)?.toInt(),
    mesa: j['mesa'] as String? ?? '',
    recinto: j['recinto'] as String?,
    parroquia: j['parroquia'] as String?,
    canton: j['canton'] as String?,
  );

  final int? mesaId;
  final String mesa;
  final String? recinto;
  final String? parroquia;
  final String? canton;

  String get lugar => [parroquia, canton].whereType<String>().join(', ');
}

class MiembroJunta {
  const MiembroJunta(this.cargo, this.nombre);

  final String? cargo;
  final String? nombre;
}

class VotosCategoria {
  const VotosCategoria(this.categoria, this.votos);

  final String categoria;
  final int votos;
}

class ResultadosMesa {
  const ResultadosMesa({
    required this.sufragantes,
    required this.votosRegistrados,
    required this.votosValidos,
    required this.votosBlancos,
    required this.votosNulos,
    required this.categorias,
  });

  factory ResultadosMesa.desdeJson(Map<String, dynamic> j) => ResultadosMesa(
    sufragantes: _entero(j['sufragantes']),
    votosRegistrados: _entero(j['votosRegistrados']),
    votosValidos: _entero(j['votosValidos']),
    votosBlancos: _entero(j['votosBlancos']),
    votosNulos: _entero(j['votosNulos']),
    categorias: [
      for (final c in (j['categorias'] as List<dynamic>? ?? const []))
        VotosCategoria(
          (c as Map<String, dynamic>)['categoria'] as String? ?? '',
          _entero(c['votos']),
        ),
    ],
  );

  final int sufragantes;
  final int votosRegistrados;
  final int votosValidos;
  final int votosBlancos;
  final int votosNulos;
  final List<VotosCategoria> categorias;
}

class MesaPresidente {
  const MesaPresidente({
    required this.proceso,
    required this.ubicacion,
    required this.estado,
    required this.electores,
    required this.junta,
    this.fechaApertura,
    this.fechaCierre,
    this.resultados,
  });

  factory MesaPresidente.desdeJson(Map<String, dynamic> j) => MesaPresidente(
    proceso: Proceso.desdeJson(j['proceso'] as Map<String, dynamic>),
    ubicacion: Ubicacion.desdeJson(j['ubicacion'] as Map<String, dynamic>),
    estado: j['estado'] as String? ?? 'PENDIENTE',
    electores: _entero(j['electores']),
    fechaApertura: _fecha(j['fechaApertura']),
    fechaCierre: _fecha(j['fechaCierre']),
    junta: [
      for (final m in (j['junta'] as List<dynamic>? ?? const []))
        MiembroJunta(
          (m as Map<String, dynamic>)['cargo'] as String?,
          m['nombre'] as String?,
        ),
    ],
    resultados: j['resultados'] == null
        ? null
        : ResultadosMesa.desdeJson(j['resultados'] as Map<String, dynamic>),
  );

  final Proceso proceso;
  final Ubicacion ubicacion;
  final String estado;
  final int electores;
  final DateTime? fechaApertura;
  final DateTime? fechaCierre;
  final List<MiembroJunta> junta;
  final ResultadosMesa? resultados;
}

class Elector {
  const Elector({required this.nombre, this.iglesia, this.sufrago});

  factory Elector.desdeJson(Map<String, dynamic> j) => Elector(
    nombre: j['nombre'] as String? ?? '',
    iglesia: j['iglesia'] as String?,
    sufrago: j['sufrago'] as bool?,
  );

  final String nombre;
  final String? iglesia;
  final bool? sufrago;
}

class IglesiaResumen {
  const IglesiaResumen({
    required this.nombre,
    this.comunidad,
    this.parroquia,
    this.canton,
    this.provincia,
    required this.totalMiembros,
    required this.habilitados,
    required this.noHabilitados,
    required this.informacionCompleta,
    required this.pendientesRevision,
    required this.enOtraIglesia,
    this.permiteEdicion = false,
  });

  factory IglesiaResumen.desdeJson(Map<String, dynamic> j) => IglesiaResumen(
    permiteEdicion: j['permiteEdicion'] as bool? ?? false,
    nombre: j['nombre'] as String? ?? '',
    comunidad: j['comunidad'] as String?,
    parroquia: j['parroquia'] as String?,
    canton: j['canton'] as String?,
    provincia: j['provincia'] as String?,
    totalMiembros: _entero(j['totalMiembros']),
    habilitados: _entero(j['miembrosHabilitados']),
    noHabilitados: _entero(j['miembrosNoHabilitados']),
    informacionCompleta: _entero(j['informacionCompleta']),
    pendientesRevision: _entero(j['pendientesRevision']),
    enOtraIglesia: _entero(j['enOtraIglesia']),
  );

  final String nombre;
  final String? comunidad;
  final String? parroquia;
  final String? canton;
  final String? provincia;
  final int totalMiembros;
  final int habilitados;
  final int noHabilitados;
  final int informacionCompleta;
  final int pendientesRevision;
  final int enOtraIglesia;

  /// El cronograma vigente permite cambiar la habilitación de los miembros.
  final bool permiteEdicion;

  String get lugar =>
      [parroquia, canton, provincia].whereType<String>().join(', ');
}

class Miembro {
  const Miembro({
    required this.id,
    required this.nombre,
    this.sexo,
    required this.habilitado,
    required this.revisado,
  });

  factory Miembro.desdeJson(Map<String, dynamic> j) => Miembro(
    id: _entero(j['id']),
    nombre: j['nombre'] as String? ?? '',
    sexo: j['sexo'] as String?,
    habilitado: j['habilitado'] as bool? ?? false,
    revisado: j['revisado'] as bool? ?? false,
  );

  final int id;
  final String nombre;

  /// `M`, `F` o `null` (valor almacenado en TEC).
  final String? sexo;
  final bool habilitado;
  final bool revisado;
}

/// Datos editables de la persona de un miembro (`GET /tribunal/iglesia/miembros/{id}`).
class MiembroDetalle {
  const MiembroDetalle({
    required this.id,
    required this.nombre,
    required this.nombres,
    required this.documento,
    required this.sexo,
    required this.habilitado,
    required this.revisado,
    required this.permiteEdicion,
  });

  factory MiembroDetalle.desdeJson(Map<String, dynamic> j) => MiembroDetalle(
    id: _entero(j['id']),
    nombre: j['nombre'] as String? ?? j['nombres'] as String? ?? '',
    nombres: j['nombres'] as String? ?? '',
    documento: j['documento'] as String? ?? '',
    sexo: j['sexo'] as String?,
    habilitado: j['habilitado'] as bool? ?? false,
    revisado: j['revisado'] as bool? ?? false,
    permiteEdicion: j['permiteEdicion'] as bool? ?? false,
  );

  final int id;

  /// Nombre para mostrar, igual que en la lista (apellidos y nombres).
  final String nombre;

  /// «Apellidos y Nombres», igual que el formulario web.
  final String nombres;
  final String documento;

  /// `M`, `F` o `null`.
  final String? sexo;
  final bool habilitado;
  final bool revisado;

  /// El cronograma vigente permite editar el padrón.
  final bool permiteEdicion;
}

class PaginaMiembros {
  const PaginaMiembros({required this.total, required this.elementos});

  factory PaginaMiembros.desdeJson(Map<String, dynamic> j) => PaginaMiembros(
    total: _entero(j['total']),
    elementos: [
      for (final e in (j['elementos'] as List<dynamic>? ?? const []))
        Miembro.desdeJson(e as Map<String, dynamic>),
    ],
  );

  final int total;
  final List<Miembro> elementos;
}

class ResumenProceso {
  const ResumenProceso({
    required this.proceso,
    required this.iglesias,
    required this.recintos,
    required this.mesas,
    required this.electores,
    required this.mesasConJuntaCompleta,
    required this.mesasCerradas,
    required this.porcentajeEscrutinio,
    required this.mesasPorEstado,
    this.alertas = const [],
  });

  factory ResumenProceso.desdeJson(Map<String, dynamic> j) => ResumenProceso(
    alertas: [
      for (final a in (j['alertas'] as List<dynamic>? ?? const []))
        AlertaProceso.desdeJson(a as Map<String, dynamic>),
    ],
    proceso: Proceso.desdeJson(j['proceso'] as Map<String, dynamic>),
    iglesias: _entero(j['iglesias']),
    recintos: _entero(j['recintos']),
    mesas: _entero(j['mesas']),
    electores: _entero(j['electores']),
    mesasConJuntaCompleta: _entero(j['mesasConJuntaCompleta']),
    mesasCerradas: _entero(j['mesasCerradas']),
    porcentajeEscrutinio: _entero(j['porcentajeEscrutinio']),
    mesasPorEstado: {
      for (final e
          in (j['mesasPorEstado'] as Map<String, dynamic>? ?? const {}).entries)
        e.key: _entero(e.value),
    },
  );

  final Proceso proceso;
  final int iglesias;
  final int recintos;
  final int mesas;
  final int electores;
  final int mesasConJuntaCompleta;
  final int mesasCerradas;
  final int porcentajeEscrutinio;
  final Map<String, int> mesasPorEstado;

  /// Pendientes operativos (mismas alertas que el dashboard web).
  final List<AlertaProceso> alertas;
}

class AlertaProceso {
  const AlertaProceso({
    required this.texto,
    required this.cantidad,
    required this.critica,
  });

  factory AlertaProceso.desdeJson(Map<String, dynamic> j) => AlertaProceso(
    texto: j['texto'] as String? ?? '',
    cantidad: _entero(j['cantidad']),
    critica: j['severidad'] == 'danger',
  );

  final String texto;
  final int cantidad;

  /// danger en TEC (sin padrón, mesas observadas o anuladas…); el resto son advertencias.
  final bool critica;
}

/// Detalle de una mesa para Administrador y Tribunal, con el acta física a revisar.
class DetalleMesa {
  const DetalleMesa({
    required this.ubicacion,
    required this.estado,
    required this.electores,
    required this.junta,
    required this.conteo,
    required this.puedeRevisarActa,
    this.fechaApertura,
    this.fechaCierre,
    this.votosRegistrados,
    this.votosValidos,
    this.votosBlancos,
    this.votosNulos,
    this.cuadre,
    this.observacionConteo,
    this.actaFisica,
    this.fase,
  });

  factory DetalleMesa.desdeJson(Map<String, dynamic> j) => DetalleMesa(
    ubicacion: Ubicacion.desdeJson(j['ubicacion'] as Map<String, dynamic>),
    estado: j['estado'] as String? ?? 'PENDIENTE',
    electores: _entero(j['electores']),
    fechaApertura: _fecha(j['fechaApertura']),
    fechaCierre: _fecha(j['fechaCierre']),
    junta: [
      for (final m in (j['junta'] as List<dynamic>? ?? const []))
        MiembroJunta(
          (m as Map<String, dynamic>)['cargo'] as String?,
          m['nombre'] as String?,
        ),
    ],
    conteo: [
      for (final c in (j['conteo'] as List<dynamic>? ?? const []))
        VotosCategoria(
          (c as Map<String, dynamic>)['categoria'] as String? ?? '',
          _entero(c['votos']),
        ),
    ],
    votosRegistrados: (j['votosRegistrados'] as num?)?.toInt(),
    votosValidos: (j['votosValidos'] as num?)?.toInt(),
    votosBlancos: (j['votosBlancos'] as num?)?.toInt(),
    votosNulos: (j['votosNulos'] as num?)?.toInt(),
    cuadre: (j['cuadre'] as num?)?.toInt(),
    observacionConteo: j['observacionConteo'] as String?,
    actaFisica: j['actaFisica'] == null
        ? null
        : ActaFisicaInfo.desdeJson(j['actaFisica'] as Map<String, dynamic>),
    puedeRevisarActa: j['puedeRevisarActa'] as bool? ?? false,
    fase: FaseEscrutinio.opcional(j['fase']),
  );

  final Ubicacion ubicacion;
  final String estado;
  final int electores;
  final DateTime? fechaApertura;
  final DateTime? fechaCierre;
  final List<MiembroJunta> junta;
  final List<VotosCategoria> conteo;
  final int? votosRegistrados;
  final int? votosValidos;
  final int? votosBlancos;
  final int? votosNulos;
  final int? cuadre;
  final String? observacionConteo;
  final ActaFisicaInfo? actaFisica;

  /// Mesa cerrada con acta física vigente aún no validada (lo decide TEC).
  final bool puedeRevisarActa;
  final FaseEscrutinio? fase;
}

class AvanceMesa {
  const AvanceMesa({
    required this.ubicacion,
    required this.estado,
    required this.juntaRegistrada,
    this.fase,
  });

  factory AvanceMesa.desdeJson(Map<String, dynamic> j) => AvanceMesa(
    ubicacion: Ubicacion.desdeJson(j['ubicacion'] as Map<String, dynamic>),
    estado: j['estado'] as String? ?? 'PENDIENTE',
    juntaRegistrada: j['juntaRegistrada'] as bool? ?? false,
    fase: FaseEscrutinio.opcional(j['fase']),
  );

  final Ubicacion ubicacion;
  final String estado;
  final bool juntaRegistrada;
  final FaseEscrutinio? fase;
}

class ResultadoCategoria {
  const ResultadoCategoria({
    required this.nombre,
    required this.votos,
    required this.porcentaje,
  });

  final String nombre;
  final int votos;
  final double porcentaje;
}

class ResultadosProceso {
  const ResultadosProceso({
    required this.proceso,
    required this.mesas,
    required this.mesasCerradas,
    required this.porcentajeMesasCerradas,
    required this.votosRegistrados,
    required this.votosBlancos,
    required this.votosNulos,
    required this.categorias,
    this.actualizado,
  });

  factory ResultadosProceso.desdeJson(Map<String, dynamic> j) =>
      ResultadosProceso(
        proceso: j['proceso'] as String? ?? '',
        mesas: _entero(j['mesas']),
        mesasCerradas: _entero(j['mesasCerradas']),
        porcentajeMesasCerradas: _entero(j['porcentajeMesasCerradas']),
        votosRegistrados: _entero(j['votosRegistrados']),
        votosBlancos: _entero(j['votosBlancos']),
        votosNulos: _entero(j['votosNulos']),
        actualizado: _fecha(j['actualizado']),
        categorias: [
          for (final c in (j['categorias'] as List<dynamic>? ?? const []))
            ResultadoCategoria(
              nombre:
                  ((c as Map<String, dynamic>)['lista'] as String?) ??
                  c['categoria'] as String? ??
                  '',
              votos: _entero(c['votos']),
              porcentaje: (c['porcentaje'] as num?)?.toDouble() ?? 0,
            ),
        ],
      );

  final String proceso;
  final int mesas;
  final int mesasCerradas;
  final int porcentajeMesasCerradas;
  final int votosRegistrados;
  final int votosBlancos;
  final int votosNulos;
  final List<ResultadoCategoria> categorias;
  final DateTime? actualizado;
}

/// Una categoría del acta (lista, blancos, nulos o papeletas no utilizadas) con sus votos.
class CategoriaConteo {
  const CategoriaConteo({
    required this.categoriaId,
    required this.nombre,
    required this.papeletas,
    required this.votos,
  });

  factory CategoriaConteo.desdeJson(Map<String, dynamic> j) => CategoriaConteo(
    categoriaId: _entero(j['categoriaId']),
    nombre: j['nombre'] as String? ?? '',
    papeletas: j['papeletas'] as bool? ?? false,
    votos: _entero(j['votos']),
  );

  final int categoriaId;
  final String nombre;

  /// Papeletas no utilizadas: no son votos emitidos, pero cuentan para el cuadre.
  final bool papeletas;
  final int votos;
}

class ActaFisicaInfo {
  const ActaFisicaInfo({
    this.version,
    required this.estadoRevision,
    this.observacion,
  });

  factory ActaFisicaInfo.desdeJson(Map<String, dynamic> j) => ActaFisicaInfo(
    version: (j['version'] as num?)?.toInt(),
    estadoRevision: j['estadoRevision'] as String? ?? '',
    observacion: j['observacion'] as String?,
  );

  final int? version;
  final String estadoRevision;
  final String? observacion;

  String get etiqueta => switch (estadoRevision) {
    'PENDIENTE_REVISION' => 'Pendiente de revisión del Tribunal',
    'VALIDADA' => 'Validada: dato oficial',
    'OBSERVADA' => 'Observada por el Tribunal',
    'RECHAZADA' => 'Rechazada por el Tribunal',
    _ => estadoRevision,
  };
}

/// Fase del escrutinio calculada por TEC (misma proyección que el avance de TEC WEB).
/// La App la muestra tal cual; no reconstruye la fase a partir de estados ni indicadores.
/// Orden oficial: 1 Apertura → 2 Conteo → 3 Acta física → 4 Cierre → 5 Validación.
class FaseEscrutinio {
  const FaseEscrutinio({
    required this.fase,
    required this.numero,
    required this.etiqueta,
    required this.situacion,
    required this.severidad,
    required this.oficial,
    this.incidencia,
    this.incidenciaEtiqueta,
  });

  factory FaseEscrutinio.desdeJson(Map<String, dynamic> j) => FaseEscrutinio(
    fase: j['fase'] as String? ?? '',
    numero: _entero(j['numero']),
    etiqueta: j['etiqueta'] as String? ?? '',
    situacion: j['situacion'] as String? ?? '',
    incidencia: j['incidencia'] as String?,
    incidenciaEtiqueta: j['incidenciaEtiqueta'] as String?,
    severidad: j['severidad'] as String? ?? 'info',
    oficial: j['oficial'] as bool? ?? false,
  );

  static FaseEscrutinio? opcional(Object? j) =>
      j is Map<String, dynamic> ? FaseEscrutinio.desdeJson(j) : null;

  /// APERTURA, CONTEO, ACTA_FISICA, CIERRE o DATO_OFICIAL.
  final String fase;

  /// Posición 1..5 en el orden oficial.
  final int numero;
  final String etiqueta;
  final String situacion;

  /// OBSERVADO, ANULADO, REABIERTO, OBSERVADA o RECHAZADA; null sin incidencia.
  final String? incidencia;
  final String? incidenciaEtiqueta;

  /// success, info, warning o danger (la misma severidad que TEC WEB).
  final String severidad;
  final bool oficial;

  /// Fase con su número: «3. Acta física».
  String get titulo => '$numero. $etiqueta';

  /// Texto completo: «3. Acta física · Pendiente de carga».
  String get texto => '$titulo · $situacion';

  /// Códigos de fase de TEC (`ProgresoEscrutinioDTO.Etapa`) en el orden oficial, con el
  /// texto de TEC WEB. Solo sirve para ofrecer las cinco opciones del filtro aunque alguna
  /// no tenga mesas; la fase de cada mesa siempre llega de TEC.
  static const Map<String, String> catalogo = {
    'APERTURA': 'Apertura',
    'CONTEO': 'Conteo',
    'ACTA_FISICA': 'Acta física',
    'CIERRE': 'Cierre',
    'DATO_OFICIAL': 'Validación',
  };
}

/// Escrutinio de la mesa del Presidente. Los indicadores `puede*` los calcula TEC; la App
/// solo los usa para mostrar u ocultar acciones (TEC vuelve a validar cada paso).
class ActaPresidente {
  const ActaPresidente({
    required this.ubicacion,
    required this.estado,
    required this.sufragantes,
    required this.votosEmitidos,
    required this.papeletasNoUtilizadas,
    required this.cuadre,
    required this.categorias,
    required this.puedeAbrir,
    required this.puedeEditarConteo,
    required this.puedeCerrar,
    required this.puedeSubirActaFisica,
    this.observacionConteo,
    this.motivoBloqueoApertura,
    this.actaFisica,
    this.fase,
  });

  factory ActaPresidente.desdeJson(Map<String, dynamic> j) => ActaPresidente(
    ubicacion: Ubicacion.desdeJson(j['ubicacion'] as Map<String, dynamic>),
    estado: j['estado'] as String? ?? 'PENDIENTE',
    sufragantes: _entero(j['sufragantes']),
    votosEmitidos: _entero(j['votosEmitidos']),
    papeletasNoUtilizadas: _entero(j['papeletasNoUtilizadas']),
    cuadre: _entero(j['cuadre']),
    observacionConteo: j['observacionConteo'] as String?,
    motivoBloqueoApertura: j['motivoBloqueoApertura'] as String?,
    puedeAbrir: j['puedeAbrir'] as bool? ?? false,
    puedeEditarConteo: j['puedeEditarConteo'] as bool? ?? false,
    puedeCerrar: j['puedeCerrar'] as bool? ?? false,
    puedeSubirActaFisica: j['puedeSubirActaFisica'] as bool? ?? false,
    categorias: [
      for (final c in (j['categorias'] as List<dynamic>? ?? const []))
        CategoriaConteo.desdeJson(c as Map<String, dynamic>),
    ],
    actaFisica: j['actaFisica'] == null
        ? null
        : ActaFisicaInfo.desdeJson(j['actaFisica'] as Map<String, dynamic>),
    fase: FaseEscrutinio.opcional(j['fase']),
  );

  final Ubicacion ubicacion;
  final String estado;
  final int sufragantes;
  final int votosEmitidos;
  final int papeletasNoUtilizadas;

  /// Sufragantes − votos emitidos − papeletas no utilizadas; 0 = cuadrado.
  final int cuadre;
  final String? observacionConteo;
  final String? motivoBloqueoApertura;
  final bool puedeAbrir;
  final bool puedeEditarConteo;
  final bool puedeCerrar;
  final bool puedeSubirActaFisica;
  final List<CategoriaConteo> categorias;
  final ActaFisicaInfo? actaFisica;
  final FaseEscrutinio? fase;

  bool get cerrada => estado == 'CERRADO';
}

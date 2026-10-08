import '../../core/api/cliente_api.dart';
import '../../core/sesion/sesion_controller.dart';

/// Consultas de solo lectura del módulo Tribunal (`/tribunal/*` de TEC). TEC autoriza
/// cada una por rol y resuelve el alcance (mesa, iglesia, proceso activo) desde el usuario.
class ApiTribunal {
  ApiTribunal(this._cliente, this._sesion);

  final ClienteApi _cliente;
  final SesionController _sesion;

  Future<Map<String, dynamic>?> _get(String ruta) =>
      _sesion.autenticada((token) => _cliente.enviar('GET', ruta, token: token));

  Future<List<dynamic>> _lista(String ruta) => _sesion.autenticada(
      (token) => _cliente.enviarLista('GET', ruta, token: token));

  Future<MesaPresidente> mesaPresidente() async => MesaPresidente.desdeJson((await _get('/tribunal/presidente/mesa'))!);

  Future<List<Elector>> padronPresidente() async =>
      (await _lista('/tribunal/presidente/padron')).map((e) => Elector.desdeJson(e as Map<String, dynamic>)).toList();

  Future<IglesiaResumen> iglesia() async => IglesiaResumen.desdeJson((await _get('/tribunal/iglesia'))!);

  Future<PaginaMiembros> miembros({String? busqueda, bool? habilitado, int pagina = 0, int tamano = 30}) async {
    final consulta = Uri(queryParameters: {
      if (busqueda != null && busqueda.trim().isNotEmpty) 'busqueda': busqueda.trim(),
      if (habilitado != null) 'habilitado': '$habilitado',
      'pagina': '$pagina',
      'tamano': '$tamano',
    }).query;
    return PaginaMiembros.desdeJson((await _get('/tribunal/iglesia/miembros?$consulta'))!);
  }

  /// Habilita o deshabilita a un miembro para participar en las elecciones. TEC valida el
  /// cronograma y que el miembro sea de la iglesia del usuario, y lo marca como revisado.
  Future<Miembro> cambiarHabilitacion(int miembroId, bool habilitado) async {
    final json = await _sesion.autenticada((token) => _cliente.enviar(
        'PUT', '/tribunal/iglesia/miembros/$miembroId/habilitacion',
        token: token, cuerpo: {'habilitado': habilitado}));
    return Miembro.desdeJson(json!);
  }

  Future<ResumenProceso> resumenProceso() async => ResumenProceso.desdeJson((await _get('/tribunal/proceso/resumen'))!);

  Future<List<AvanceMesa>> avanceMesas() async =>
      (await _lista('/tribunal/proceso/mesas')).map((e) => AvanceMesa.desdeJson(e as Map<String, dynamic>)).toList();

  Future<ResultadosProceso> resultadosProceso() async =>
      ResultadosProceso.desdeJson((await _get('/tribunal/proceso/resultados'))!);
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

  static String etiqueta(String? estado) => etiquetas[estado] ?? estado ?? 'Sin estado';
}

DateTime? _fecha(Object? valor) {
  if (valor is String) return DateTime.tryParse(valor)?.toLocal();
  if (valor is num) return DateTime.fromMillisecondsSinceEpoch(valor.toInt());
  return null;
}

int _entero(Object? valor) => (valor as num?)?.toInt() ?? 0;

class Proceso {
  const Proceso({required this.nombre, this.faseVigente});

  factory Proceso.desdeJson(Map<String, dynamic> j) =>
      Proceso(nombre: j['nombre'] as String? ?? '', faseVigente: j['faseVigente'] as String?);

  final String nombre;
  final String? faseVigente;
}

class Ubicacion {
  const Ubicacion({required this.mesa, this.recinto, this.parroquia, this.canton});

  factory Ubicacion.desdeJson(Map<String, dynamic> j) => Ubicacion(
        mesa: j['mesa'] as String? ?? '',
        recinto: j['recinto'] as String?,
        parroquia: j['parroquia'] as String?,
        canton: j['canton'] as String?,
      );

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
            VotosCategoria((c as Map<String, dynamic>)['categoria'] as String? ?? '', _entero(c['votos'])),
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
            MiembroJunta((m as Map<String, dynamic>)['cargo'] as String?, m['nombre'] as String?),
        ],
        resultados: j['resultados'] == null ? null : ResultadosMesa.desdeJson(j['resultados'] as Map<String, dynamic>),
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

  factory Elector.desdeJson(Map<String, dynamic> j) =>
      Elector(nombre: j['nombre'] as String? ?? '', iglesia: j['iglesia'] as String?, sufrago: j['sufrago'] as bool?);

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

  String get lugar => [parroquia, canton, provincia].whereType<String>().join(', ');
}

class Miembro {
  const Miembro({required this.id, required this.nombre, required this.habilitado, required this.revisado});

  factory Miembro.desdeJson(Map<String, dynamic> j) => Miembro(
        id: _entero(j['id']),
        nombre: j['nombre'] as String? ?? '',
        habilitado: j['habilitado'] as bool? ?? false,
        revisado: j['revisado'] as bool? ?? false,
      );

  final int id;
  final String nombre;
  final bool habilitado;
  final bool revisado;
}

class PaginaMiembros {
  const PaginaMiembros({required this.total, required this.elementos});

  factory PaginaMiembros.desdeJson(Map<String, dynamic> j) => PaginaMiembros(
        total: _entero(j['total']),
        elementos: [for (final e in (j['elementos'] as List<dynamic>? ?? const [])) Miembro.desdeJson(e as Map<String, dynamic>)],
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
  });

  factory ResumenProceso.desdeJson(Map<String, dynamic> j) => ResumenProceso(
        proceso: Proceso.desdeJson(j['proceso'] as Map<String, dynamic>),
        iglesias: _entero(j['iglesias']),
        recintos: _entero(j['recintos']),
        mesas: _entero(j['mesas']),
        electores: _entero(j['electores']),
        mesasConJuntaCompleta: _entero(j['mesasConJuntaCompleta']),
        mesasCerradas: _entero(j['mesasCerradas']),
        porcentajeEscrutinio: _entero(j['porcentajeEscrutinio']),
        mesasPorEstado: {
          for (final e in (j['mesasPorEstado'] as Map<String, dynamic>? ?? const {}).entries) e.key: _entero(e.value),
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
}

class AvanceMesa {
  const AvanceMesa({required this.ubicacion, required this.estado, required this.juntaRegistrada});

  factory AvanceMesa.desdeJson(Map<String, dynamic> j) => AvanceMesa(
        ubicacion: Ubicacion.desdeJson(j['ubicacion'] as Map<String, dynamic>),
        estado: j['estado'] as String? ?? 'PENDIENTE',
        juntaRegistrada: j['juntaRegistrada'] as bool? ?? false,
      );

  final Ubicacion ubicacion;
  final String estado;
  final bool juntaRegistrada;
}

class ResultadoCategoria {
  const ResultadoCategoria({required this.nombre, required this.votos, required this.porcentaje});

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

  factory ResultadosProceso.desdeJson(Map<String, dynamic> j) => ResultadosProceso(
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
              nombre: ((c as Map<String, dynamic>)['lista'] as String?) ?? c['categoria'] as String? ?? '',
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

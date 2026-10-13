/// Contenido institucional de CONPOCIIECH. Solo textos publicados por la organización:
/// no se agregan autoridades, departamentos ni datos que no estén en la fuente.
///
/// Fuentes (revisadas el 13/10/2026):
/// - Portada de https://www.conpociiech.org (lema, «Quiénes somos», instituciones).
/// - https://www.conpociiech.org/tribunal-electoral/ (Tribunal Electoral).
/// - Leyenda del logo oficial (nombre completo).
///
/// Pendiente hasta que se publique en el sitio: Historia, Misión y Visión, Autoridades
/// y Contacto (sus páginas aún no existen). Una sección sin contenido no se muestra.
abstract final class ContenidoInstitucional {
  static const String sigla = 'CONPOCIIECH';
  static const String subtitulo = 'Organización Provincial de Chimborazo';
  static const String lema = 'Unidos al fortalecimiento integral';

  /// Nombre completo tal como figura en el logo oficial.
  static const String nombreCompleto =
      'Confederación de Pueblos Organizaciones Comunidades e Iglesias Indígenas '
      'Evangélicas de Chimborazo';

  static const String sitioWeb = 'www.conpociiech.org';

  static const String quienesSomos =
      'CONPOCIIECH es una organización provincial comprometida con el fortalecimiento '
      'integral de sus iglesias, promoviendo la formación, la participación y el '
      'desarrollo de sus comunidades en la provincia de Chimborazo.';

  static const String introInstituciones =
      'Conozca las instituciones que forman parte de CONPOCIIECH y que trabajan en las '
      'áreas de educación, formación, servicio y fortalecimiento de nuestras comunidades.';

  /// Instituciones por área, en el orden del menú del sitio.
  static const List<AreaInstitucional> areas = [
    AreaInstitucional('Educación', [
      Institucion(
        'Escuela de Pedagogía',
        'Formación académica orientada al desarrollo de educadores comprometidos con el '
            'servicio, los valores y el fortalecimiento de nuestras comunidades.',
      ),
      Institucion(
        'Seminario Teológico Sinaí',
        'Formación bíblica y teológica orientada a la preparación de líderes comprometidos '
            'con el servicio, la enseñanza y el fortalecimiento de las iglesias.',
      ),
      Institucion(
        'Instituto de Música Sonido Celestial',
        'Formación musical orientada al desarrollo de talentos, fortaleciendo las '
            'habilidades artísticas y el servicio en nuestras iglesias y comunidades.',
      ),
      Institucion(
        'Instituto Bíblico de Mujeres Nueva Vida',
        'Formación bíblica orientada al crecimiento espiritual y al fortalecimiento de '
            'mujeres comprometidas con el servicio en sus iglesias y comunidades.',
      ),
      Institucion(
        'UECIB Ciencia y Biblia',
        'Formación educativa integral que articula conocimientos, valores y principios '
            'para contribuir al desarrollo académico y humano de sus estudiantes.',
      ),
    ]),
    AreaInstitucional('Ministerios', [
      Institucion(
        'Pastoral Juvenil Ecuador STS',
        'Espacio de formación, participación y servicio que fortalece el liderazgo de los '
            'jóvenes y su compromiso con las iglesias y comunidades.',
      ),
    ]),
  ];

  /// Departamento publicado en el sitio (menú «Departamentos»).
  static const String tribunalElectoral =
      'Organismo encargado de desarrollar y coordinar el proceso electoral de '
      'CONPOCIIECH, garantizando el cumplimiento de la normativa y las diferentes etapas '
      'establecidas para las elecciones.';

  static const String procesoElectoral =
      'Información oficial del proceso electoral de CONPOCIIECH. Consulte las novedades, '
      'documentos, cronograma, candidaturas y resultados publicados por el Tribunal '
      'Electoral.';
}

class AreaInstitucional {
  const AreaInstitucional(this.nombre, this.instituciones);
  final String nombre;
  final List<Institucion> instituciones;
}

class Institucion {
  const Institucion(this.nombre, this.descripcion);
  final String nombre;
  final String descripcion;
}

# Modernización de CONPOCIIECH

## Auditoría y decisiones

La aplicación ya utilizaba Material 3, Montserrat y colores institucionales. Se conserva esa base y se reutilizan `Seccion`, `Dato`, `Indicadores`, `EtiquetaEstado` y `VistaConsulta`; no se crean variantes redundantes para cada entidad. El logo integrado sigue siendo el logo provisional de TEC.

Se detectaron anchos fijos de contenido e indicadores, ausencia de navegación adaptativa, filtros de miembros ocultos fuera del ancho visible y errores de recarga no visibles cuando ya existían datos. La paginación podía dejar un indicador de carga tras un error.

## Archivos y componentes

- `lib/shared/tema/tema_app.dart`: esquema Material 3 completo generado desde #034EA2, superficies neutras, campos, botones, tarjetas, diálogos, navegación y mensajes.
- `lib/shared/tema/diseno_app.dart`: espaciado, radios, breakpoints 600/1024 y ancho máximo de contenido.
- `lib/shared/widgets/estructura_adaptativa.dart`: NavigationBar móvil y NavigationRail desde 600 px. Muestra la unión de secciones de los roles existentes. Admite también pantallas abiertas mediante MaterialPageRoute.
- `lib/shared/widgets/estados_app.dart`: carga con semántica, error con reintento y vacío con icono y texto.
- `lib/shared/widgets/cabecera_app.dart`: encabezado reutilizable.
- `lib/features/tribunal/widgets_tribunal.dart`: consultas y tarjetas compartidas, métricas distribuidas según el ancho y márgenes adaptativos.
- `lib/features/tribunal/presidente/guia_escrutinio.dart`: guía de siete pasos y aviso de cambios pendientes/cierre; no crea estados ni permisos.
- Pantallas modificadas: Login, Inicio, Tribunal, Mi Iglesia, Miembros, Mi Mesa, Padrón, Escrutinio, Proceso, Avance, Detalle/revisión de actas y Resultados.
- `test/tribunal_test.dart`: expectativas actualizadas a la terminología solicitada «Habilitados / Total».
- `test/responsive_test.dart`: las diez pantallas electorales, login, seis anchos y escalado de texto 1 y 1,5; comprueba errores de layout y navegación y recorre el contenido inferior.

No se añaden dependencias. No se modifican API, endpoints, modelos, sesión, almacenamiento de tokens, roles, guardas ni reglas electorales. Se mantienen confirmaciones y bloqueo de operaciones existentes.

## Preparación electoral y contrato TEC disponible

La revisión se basa en `api_tribunal.dart`, los contratos representados en sus modelos y las pruebas con TEC simulado, no en consultas a producción.

| Indicador | Disponibilidad |
| --- | --- |
| Fase, iglesias, recintos, mesas, electores | ResumenProceso |
| Juntas completas y mesas cerradas | ResumenProceso |
| Mesas por estado y alertas | ResumenProceso; solo estados recibidos |
| Habilitados / Total y pendientes de revisión | IglesiaResumen, iglesia asignada |
| Estado del acta y revisión | DetalleMesa y ActaPresidente |
| Iglesias sin administrador | REQUIERE ENDPOINT / CAMBIO EN TEC |
| Administradores pendientes de activar | REQUIERE ENDPOINT / CAMBIO EN TEC |
| Administradores sin acceso reciente | REQUIERE ENDPOINT / CAMBIO EN TEC |
| Habilitados / Total y revisión de todas las iglesias | REQUIERE ENDPOINT / CAMBIO EN TEC |
| Mesas listas como indicador de preparación | REQUIERE ENDPOINT / CAMBIO EN TEC; no se equipara automáticamente a junta completa |

Los indicadores ausentes no se simulan ni se muestran como cero. Las actas no se confunden con estados de escrutinio de mesas.

## Resultados de validación

- `flutter test`: 89 pruebas aprobadas, incluyendo 12 combinaciones de ancho y escalado de texto.
- Tamaños: 360, 390, 430, 600, 768 y 1024 px; tablets/pantallas grandes con 600 px de alto.
- `git diff --check`: sin problemas de espacios.
- No se realizaron compilaciones de distribución Android/iOS ni pruebas con TEC de producción.

## Validación y pendientes de publicación

`dart format .` encuentra una ruta generada de Firebase inaccesible dentro de build. Se formatea el código fuente y las pruebas con `dart format lib test`; los cambios exclusivamente de formato en archivos de seguridad se descartan para conservar el alcance.

Las pruebas de widgets verifican layout y flujos con el servidor simulado. No sustituyen la revisión visual en dispositivos Android/iOS, TalkBack/VoiceOver, teclado real, permisos de cámara, integración TEC, firma y distribución. Se debe incorporar el logo definitivo antes de publicar si corresponde.

Resultado final de flutter analyze: sin incidencias.

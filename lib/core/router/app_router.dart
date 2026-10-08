import 'package:go_router/go_router.dart';

import '../../features/auth/pantalla_cambiar_clave.dart';
import '../../features/auth/pantalla_iniciar_sesion.dart';
import '../../features/inicio/pantalla_inicio.dart';
import '../../features/tribunal/iglesia/pantallas_iglesia.dart';
import '../../features/tribunal/pantalla_tribunal.dart';
import '../../features/tribunal/presidente/pantallas_presidente.dart';
import '../../features/tribunal/proceso/pantallas_proceso.dart';
import '../sesion/roles.dart';
import '../sesion/sesion_controller.dart';

/// Rutas de la App. El área pública no exige sesión; cada módulo protegido declara su
/// guarda. La guarda solo decide qué se muestra: TEC vuelve a autorizar cada petición.
abstract final class Rutas {
  static const String inicio = '/';
  static const String iniciarSesion = '/iniciar-sesion';
  static const String cambiarClave = '/cambiar-clave';
  static const String tribunal = '/tribunal';
  static const String miMesa = '/tribunal/mesa';
  static const String padronMesa = '/tribunal/mesa/padron';
  static const String miIglesia = '/tribunal/iglesia';
  static const String miembrosIglesia = '/tribunal/iglesia/miembros';
  static const String proceso = '/tribunal/proceso';
  static const String avanceMesas = '/tribunal/proceso/mesas';
  static const String resultados = '/tribunal/proceso/resultados';

  /// Parámetro con la ruta a la que se vuelve después de iniciar sesión.
  static const String destino = 'destino';

  /// Roles de cada sección del módulo Tribunal.
  static const Map<String, Set<String>> rolesPorSeccion = {
    miMesa: RolTec.seccionMesa,
    miIglesia: RolTec.seccionIglesia,
    proceso: RolTec.seccionProceso,
  };
}

GoRouter crearRouter(SesionController sesion) {
  return GoRouter(
    initialLocation: Rutas.inicio,
    refreshListenable: sesion,
    redirect: (context, estado) => guardaRutas(sesion, estado.uri),
    routes: [
      GoRoute(path: Rutas.inicio, builder: (context, estado) => const PantallaInicio()),
      GoRoute(
        path: Rutas.iniciarSesion,
        builder: (context, estado) =>
            PantallaIniciarSesion(destino: estado.uri.queryParameters[Rutas.destino]),
      ),
      GoRoute(path: Rutas.cambiarClave, builder: (context, estado) => const PantallaCambiarClave()),
      GoRoute(
        path: Rutas.tribunal,
        builder: (context, estado) => const PantallaTribunal(),
        routes: [
          GoRoute(
            path: 'mesa',
            builder: (context, estado) => const PantallaMiMesa(),
            routes: [GoRoute(path: 'padron', builder: (context, estado) => const PantallaPadronMesa())],
          ),
          GoRoute(
            path: 'iglesia',
            builder: (context, estado) => const PantallaMiIglesia(),
            routes: [GoRoute(path: 'miembros', builder: (context, estado) => const PantallaMiembrosIglesia())],
          ),
          GoRoute(
            path: 'proceso',
            builder: (context, estado) => const PantallaProceso(),
            routes: [
              GoRoute(path: 'mesas', builder: (context, estado) => const PantallaAvanceMesas()),
              GoRoute(path: 'resultados', builder: (context, estado) => const PantallaResultados()),
            ],
          ),
        ],
      ),
    ],
  );
}

String? guardaRutas(SesionController sesion, Uri uri) {
  final ruta = uri.path;

  // Usuario no permanente: igual que en la web, solo puede cambiar su clave.
  if (sesion.cambioClaveObligatorio) {
    return ruta == Rutas.cambiarClave ? null : Rutas.cambiarClave;
  }
  if (ruta == Rutas.cambiarClave && !sesion.autenticado) {
    return Uri(path: Rutas.iniciarSesion, queryParameters: {Rutas.destino: ruta}).toString();
  }
  if (ruta == Rutas.iniciarSesion && sesion.autenticado) {
    return destinoSeguro(uri.queryParameters[Rutas.destino], sesion);
  }
  if (ruta == Rutas.tribunal || ruta.startsWith('${Rutas.tribunal}/')) {
    if (!sesion.autenticado) {
      return Uri(path: Rutas.iniciarSesion, queryParameters: {Rutas.destino: ruta}).toString();
    }
    // Autenticado sin un rol del módulo: no se muestra (unión de permisos de sus roles).
    if (!sesion.puedeAccederTribunal) return Rutas.inicio;
    for (final seccion in Rutas.rolesPorSeccion.entries) {
      if ((ruta == seccion.key || ruta.startsWith('${seccion.key}/')) && !sesion.tieneAlgunRol(seccion.value)) {
        return Rutas.tribunal;
      }
    }
  }
  return null;
}

/// Destino tras autenticarse: solo rutas internas conocidas; si no, el módulo disponible.
String destinoSeguro(String? destino, SesionController sesion) {
  const internas = {
    Rutas.inicio,
    Rutas.cambiarClave,
    Rutas.tribunal,
    Rutas.miMesa,
    Rutas.padronMesa,
    Rutas.miIglesia,
    Rutas.miembrosIglesia,
    Rutas.proceso,
    Rutas.avanceMesas,
    Rutas.resultados,
  };
  if (destino != null && internas.contains(destino)) return destino;
  return sesion.puedeAccederTribunal ? Rutas.tribunal : Rutas.inicio;
}

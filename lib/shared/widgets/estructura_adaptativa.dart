import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/router/app_router.dart';
import '../../core/sesion/roles.dart';
import '../../core/sesion/sesion_controller.dart';
import '../tema/diseno_app.dart';

/// Navegación de presentación. Las guardas y la autorización TEC siguen vigentes.
class EstructuraAdaptativa extends StatelessWidget {
  const EstructuraAdaptativa({
    super.key,
    required this.appBar,
    required this.body,
  });
  final PreferredSizeWidget appBar;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final sesion = context.watch<SesionController>();
    final destinos = <(String, String, IconData)>[
      (Rutas.tribunal, 'Panel', Icons.dashboard_outlined),
      if (sesion.tieneAlgunRol(RolTec.seccionMesa))
        (Rutas.miMesa, 'Mesa', Icons.how_to_vote_outlined),
      if (sesion.tieneAlgunRol(RolTec.seccionIglesia))
        (Rutas.miIglesia, 'Iglesia', Icons.church_outlined),
      if (sesion.tieneAlgunRol(RolTec.seccionProceso))
        (Rutas.proceso, 'Proceso', Icons.insights_outlined),
    ];
    final router = GoRouter.maybeOf(context);
    if (router == null) {
      return Scaffold(
        appBar: appBar,
        body: SafeArea(child: body),
      );
    }
    final ruta = router.routerDelegate.currentConfiguration.uri.path;
    var seleccionado = 0;
    for (var i = 1; i < destinos.length; i++) {
      if (ruta == destinos[i].$1 || ruta.startsWith('${destinos[i].$1}/')) {
        seleccionado = i;
      }
    }
    void navegar(int i) {
      if (i != seleccionado) context.go(destinos[i].$1);
    }

    return LayoutBuilder(
      builder: (context, limites) {
        final amplia = limites.maxWidth >= DisenoApp.tablet;
        final contenido = SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: DisenoApp.anchoContenido,
              ),
              child: body,
            ),
          ),
        );
        return Scaffold(
          appBar: appBar,
          body: amplia
              ? Row(
                  children: [
                    NavigationRail(
                      selectedIndex: seleccionado,
                      onDestinationSelected: navegar,
                      labelType: NavigationRailLabelType.all,
                      destinations: [
                        for (final d in destinos)
                          NavigationRailDestination(
                            icon: Icon(d.$3),
                            label: Text(d.$2),
                          ),
                      ],
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: contenido),
                  ],
                )
              : contenido,
          bottomNavigationBar: amplia
              ? null
              : NavigationBar(
                  selectedIndex: seleccionado,
                  onDestinationSelected: navegar,
                  destinations: [
                    for (final d in destinos)
                      NavigationDestination(icon: Icon(d.$3), label: d.$2),
                  ],
                ),
        );
      },
    );
  }
}

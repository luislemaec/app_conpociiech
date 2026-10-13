import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../tema/colores_tribunal.dart';
import '../tema/diseno_app.dart';
import 'logo_institucional.dart';

/// Navegación institucional: Inicio · Organización · Servicios. Barra inferior en
/// teléfonos y riel lateral en tablets; cada pestaña conserva su estado y posición.
/// El módulo Tribunal, el inicio de sesión y el cambio de clave quedan fuera de esta
/// estructura, con sus propias guardas.
class EstructuraPrincipal extends StatelessWidget {
  const EstructuraPrincipal({super.key, required this.navegacion});

  final StatefulNavigationShell navegacion;

  static const List<(String, IconData, IconData)> secciones = [
    ('Inicio', Icons.home_outlined, Icons.home),
    ('Organización', Icons.account_balance_outlined, Icons.account_balance),
    ('Servicios', Icons.apps_outlined, Icons.apps),
  ];

  void _ir(int indice) {
    // Tocar la pestaña actual vuelve a su pantalla inicial.
    navegacion.goBranch(indice, initialLocation: indice == navegacion.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    final indice = navegacion.currentIndex;
    return LayoutBuilder(
      builder: (context, limites) {
        final amplia = limites.maxWidth >= DisenoApp.tablet;
        final contenido = SafeArea(
          top: false,
          child: _Desvanecer(indice: indice, child: navegacion),
        );
        return Scaffold(
          appBar: AppBar(
            titleSpacing: DisenoApp.md,
            title: Row(
              children: [
                const LogoInstitucional(ancho: 34),
                const SizedBox(width: DisenoApp.sm + DisenoApp.xs),
                Flexible(child: Text(secciones[indice].$1, overflow: TextOverflow.ellipsis)),
              ],
            ),
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Divider(height: 1, color: ColoresTribunal.borde),
            ),
          ),
          body: amplia
              ? Row(
                  children: [
                    NavigationRail(
                      selectedIndex: indice,
                      onDestinationSelected: _ir,
                      labelType: NavigationRailLabelType.all,
                      destinations: [
                        for (final s in secciones)
                          NavigationRailDestination(
                            icon: Icon(s.$2),
                            selectedIcon: Icon(s.$3),
                            label: Text(s.$1),
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
                  selectedIndex: indice,
                  onDestinationSelected: _ir,
                  destinations: [
                    for (final s in secciones)
                      NavigationDestination(icon: Icon(s.$2), selectedIcon: Icon(s.$3), label: s.$1),
                  ],
                ),
        );
      },
    );
  }
}

/// Transición suave al cambiar de pestaña (adaptada de `_FadeIndexedStack` de app_consejo).
class _Desvanecer extends StatefulWidget {
  const _Desvanecer({required this.indice, required this.child});

  final int indice;
  final Widget child;

  @override
  State<_Desvanecer> createState() => _DesvanecerState();
}

class _DesvanecerState extends State<_Desvanecer> with SingleTickerProviderStateMixin {
  late final AnimationController _control =
      AnimationController(vsync: this, duration: DisenoApp.estandar, value: 1);

  @override
  void didUpdateWidget(_Desvanecer anterior) {
    super.didUpdateWidget(anterior);
    final reducir = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (anterior.indice != widget.indice && !reducir) _control.forward(from: 0);
  }

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(opacity: _control, child: widget.child);
}

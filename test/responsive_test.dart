import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:app_conpociiech/app.dart';
import 'package:app_conpociiech/core/config/entorno.dart';
import 'package:app_conpociiech/core/router/app_router.dart';
import 'package:app_conpociiech/core/sesion/roles.dart';
import 'tec_simulado.dart';

void main() {
  for (final ancho in [360.0, 390.0, 430.0, 600.0, 768.0, 1024.0]) {
    for (final escala in [1.0, 1.5]) {
      testWidgets('Pantallas a $ancho px, texto $escala', (tester) async {
        tester.view.physicalSize = Size(ancho, ancho >= 600 ? 600 : 1000);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = escala;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final tec = TecSimulado()
          ..usuarios['varios'] = UsuarioSimulado(
            clave: 'Clave123',
            roles: [
              RolTec.presidenteMesa,
              RolTec.iglesiaAdmin,
              RolTec.tribunal,
            ],
          );
        final sesion = tec.crearSesion();
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(escala)),
            child: AppConpociiech(
              entorno: Entorno.desdeUrl(Entorno.urlPorDefecto),
              sesion: sesion,
              cliente: tec.api,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
        router.go(Rutas.iniciarSesion);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.runAsync(() => sesion.iniciarSesion('varios', 'Clave123'));
        for (final ruta in [
          Rutas.inicio,
          Rutas.organizacion,
          Rutas.servicios,
          Rutas.tribunal,
          Rutas.proceso,
          Rutas.miIglesia,
          Rutas.miembrosIglesia,
          Rutas.miMesa,
          Rutas.padronMesa,
          Rutas.escrutinio,
          Rutas.avanceMesas,
          Rutas.detalleMesa(7),
          Rutas.resultados,
        ]) {
          router.go(ruta);
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 30)),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: ruta);
          expect(
            find.byType(ancho >= 600 ? NavigationRail : NavigationBar),
            findsOneWidget,
          );
          for (final scroll in find.byType(Scrollable).evaluate().toList()) {
            final state = (scroll as StatefulElement).state as ScrollableState;
            if (state.position.axis == Axis.vertical &&
                state.position.hasContentDimensions) {
              state.position.jumpTo(state.position.maxScrollExtent);
              await tester.pump();
              expect(
                tester.takeException(),
                isNull,
                reason: 'Contenido inferior: $ruta',
              );
            }
          }
        }
        await tester.pumpWidget(const SizedBox());
        sesion.dispose();
        tec.cliente.close();
      });
    }
  }
}

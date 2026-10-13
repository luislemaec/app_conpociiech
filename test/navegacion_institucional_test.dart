import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:app_conpociiech/app.dart';
import 'package:app_conpociiech/core/config/entorno.dart';
import 'package:app_conpociiech/core/router/app_router.dart';
import 'package:app_conpociiech/core/sesion/roles.dart';
import 'package:app_conpociiech/core/sesion/sesion_controller.dart';
import 'package:app_conpociiech/features/organizacion/contenido_institucional.dart';
import 'package:app_conpociiech/features/tribunal/pantalla_tribunal.dart';
import 'package:app_conpociiech/shared/widgets/logo_institucional.dart';

import 'tec_simulado.dart';

late TecSimulado tec;

Future<SesionController> montarApp(WidgetTester tester, {String? usuario}) async {
  // Teléfono: barra de navegación inferior.
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final sesion = tec.crearSesion();
  if (usuario != null) await tester.runAsync(() => sesion.iniciarSesion(usuario, 'Clave123'));
  await tester.pumpWidget(AppConpociiech(entorno: Entorno.desdeUrl(Entorno.urlPorDefecto), sesion: sesion, cliente: tec.api));
  await tester.pumpAndSettle();
  return sesion;
}

Future<void> tocar(WidgetTester tester, Finder objetivo) async {
  await tester.ensureVisible(objetivo);
  await tester.pumpAndSettle();
  await tester.tap(objetivo);
  await tester.runAsync(() => pumpEventQueue());
  await tester.pumpAndSettle();
}

Finder pestana(String nombre) => find.descendant(of: find.byType(NavigationBar), matching: find.text(nombre));

void main() {
  setUp(() {
    tec = TecSimulado()
      ..usuarios['iglesia'] = UsuarioSimulado(clave: 'Clave123', roles: [RolTec.iglesiaAdmin])
      ..usuarios['presidente'] = UsuarioSimulado(clave: 'Clave123', roles: [RolTec.presidenteMesa])
      ..usuarios['otro'] = UsuarioSimulado(clave: 'Clave123', roles: ['Usuario']);
  });

  testWidgets('Inicio muestra el logo oficial y las tres pestañas', (tester) async {
    await montarApp(tester);
    expect(find.byType(LogoInstitucional), findsWidgets);
    expect(find.text(ContenidoInstitucional.lema), findsOneWidget);
    for (final nombre in ['Inicio', 'Organización', 'Servicios']) {
      expect(pestana(nombre), findsOneWidget);
    }
  });

  testWidgets('Organización muestra solo el contenido publicado', (tester) async {
    await montarApp(tester);
    await tocar(tester, pestana('Organización'));
    expect(find.text(ContenidoInstitucional.quienesSomos), findsOneWidget);
    for (final area in ContenidoInstitucional.areas) {
      for (final institucion in area.instituciones) {
        await tester.scrollUntilVisible(find.text(institucion.nombre), 200,
            scrollable: find.byType(Scrollable).last);
        expect(find.text(institucion.nombre), findsOneWidget);
      }
    }
    // Sin contenido publicado: no se muestran.
    expect(find.text('MISIÓN'), findsNothing);
    expect(find.text('AUTORIDADES'), findsNothing);
  });

  testWidgets('Servicios sin sesión lleva al inicio de sesión y vuelve al Tribunal', (tester) async {
    await montarApp(tester);
    await tocar(tester, pestana('Servicios'));
    expect(find.text('Requiere iniciar sesión'), findsOneWidget);
    await tocar(tester, find.text('Sistema del Tribunal Electoral (TEC)'));
    expect(find.text('Ingresar'), findsOneWidget);
    expect(find.byType(LogoTribunal), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), 'iglesia');
    await tester.enterText(find.byType(TextFormField).at(1), 'Clave123');
    await tocar(tester, find.text('Ingresar'));
    expect(find.byType(PantallaTribunal), findsOneWidget);
  });

  testWidgets('Servicios muestra solo las secciones de los roles del usuario', (tester) async {
    await montarApp(tester, usuario: 'iglesia');
    await tocar(tester, pestana('Servicios'));
    expect(find.text('Mi iglesia'), findsOneWidget);
    expect(find.text('Mi mesa'), findsNothing);
    await tester.scrollUntilVisible(find.text('Cambiar contraseña'), 200, scrollable: find.byType(Scrollable).last);
    expect(find.text('Cambiar contraseña'), findsOneWidget);
  });

  testWidgets('usuario sin rol del Tribunal no recibe acceso desde Servicios', (tester) async {
    await montarApp(tester, usuario: 'otro');
    await tocar(tester, pestana('Servicios'));
    expect(find.textContaining('no tiene funciones del Tribunal Electoral'), findsOneWidget);
    expect(find.text('Mi mesa'), findsNothing);
    expect(find.text('Mi iglesia'), findsNothing);
  });

  testWidgets('«Atrás» del módulo Tribunal vuelve a Servicios', (tester) async {
    await montarApp(tester, usuario: 'presidente');
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go(Rutas.tribunal);
    await tester.pumpAndSettle();
    expect(find.byType(LogoTribunal), findsOneWidget);
    await tocar(tester, find.byTooltip('Servicios'));
    expect(find.byType(PantallaTribunal), findsNothing);
    expect(find.text('Servicios electorales'.toUpperCase()), findsOneWidget);
  });
}

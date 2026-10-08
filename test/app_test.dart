import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:app_conpociiech/app.dart';
import 'package:app_conpociiech/core/config/entorno.dart';
import 'package:app_conpociiech/core/router/app_router.dart';
import 'package:app_conpociiech/core/sesion/roles.dart';
import 'package:app_conpociiech/core/sesion/sesion_controller.dart';
import 'package:app_conpociiech/features/tribunal/pantalla_tribunal.dart';

import 'tec_simulado.dart';


late TecSimulado tec;

Future<SesionController> montarApp(WidgetTester tester, {String? usuario, String clave = 'Clave123'}) async {
  final sesion = tec.crearSesion();
  if (usuario != null) await tester.runAsync(() => sesion.iniciarSesion(usuario, clave));
  await tester.pumpWidget(AppConpociiech(entorno: Entorno.desdeUrl(Entorno.urlPorDefecto), sesion: sesion, cliente: tec.api));
  await tester.pumpAndSettle();
  return sesion;
}

void irA(WidgetTester tester, String ruta) {
  GoRouter.of(tester.element(find.byType(Scaffold).first)).go(ruta);
}

/// Toca un botón y espera la respuesta del servidor simulado.
Future<void> tocarYEsperar(WidgetTester tester, Finder boton) async {
  await tester.ensureVisible(boton);
  await tester.pumpAndSettle();
  await tester.tap(boton);
  await tester.runAsync(() => pumpEventQueue());
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    tec = TecSimulado()
      ..usuarios['presidente'] = UsuarioSimulado(clave: 'Clave123', roles: [RolTec.presidenteMesa])
      ..usuarios['iglesia'] = UsuarioSimulado(clave: 'Clave123', roles: [RolTec.iglesiaAdmin])
      ..usuarios['otro'] = UsuarioSimulado(clave: 'Clave123', roles: ['Usuario'])
      ..usuarios['nuevo'] = UsuarioSimulado(clave: 'Temporal1', roles: [RolTec.tribunal], permanente: false);
  });

  group('Inicio público', () {
    testWidgets('muestra la identidad y solo «Iniciar sesión»', (tester) async {
      await montarApp(tester);
      expect(find.text('CONPOCIIECH'), findsOneWidget);
      expect(find.text('Iniciar sesión'), findsOneWidget);
      expect(find.text('Tribunal Electoral'), findsNothing);
    });

    testWidgets('«Iniciar sesión» abre el formulario', (tester) async {
      await montarApp(tester);
      await tester.tap(find.text('Iniciar sesión'));
      await tester.pumpAndSettle();
      expect(find.text('Ingresar'), findsOneWidget);
    });
  });

  group('Guardas del módulo Tribunal', () {
    testWidgets('sin sesión redirige al inicio de sesión', (tester) async {
      await montarApp(tester);
      irA(tester, Rutas.tribunal);
      await tester.pumpAndSettle();
      expect(find.text('Ingresar'), findsOneWidget);
      expect(find.byType(PantallaTribunal), findsNothing);
    });

    testWidgets('con un rol del módulo permite el acceso', (tester) async {
      await montarApp(tester, usuario: 'iglesia');
      await tester.tap(find.text('Tribunal Electoral'));
      await tester.pumpAndSettle();
      expect(find.byType(PantallaTribunal), findsOneWidget);
      expect(find.text('Persona iglesia'), findsOneWidget);
    });

    testWidgets('autenticado sin rol del módulo no lo ve ni puede entrar', (tester) async {
      await montarApp(tester, usuario: 'otro');
      expect(find.text('Tribunal Electoral'), findsNothing);
      irA(tester, Rutas.tribunal);
      await tester.pumpAndSettle();
      expect(find.text('CONPOCIIECH'), findsOneWidget);
    });

    testWidgets('cerrar sesión desde el módulo vuelve a exigir autenticación', (tester) async {
      await montarApp(tester, usuario: 'presidente');
      irA(tester, Rutas.tribunal);
      await tester.pumpAndSettle();
      await tocarYEsperar(tester, find.byTooltip('Cerrar sesión'));
      expect(find.text('Ingresar'), findsOneWidget);
      expect(tec.rutas.last, '/auth/logout');
    });
  });

  group('Formulario de inicio de sesión', () {
    testWidgets('valida campos obligatorios', (tester) async {
      await montarApp(tester);
      irA(tester, Rutas.iniciarSesion);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ingresar'));
      await tester.pumpAndSettle();
      expect(find.text('Ingrese su usuario.'), findsOneWidget);
      expect(find.text('Ingrese su contraseña.'), findsOneWidget);
    });

    testWidgets('credenciales incorrectas: mensaje de TEC y contraseña descartada', (tester) async {
      final sesion = await montarApp(tester);
      irA(tester, Rutas.iniciarSesion);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'presidente');
      await tester.enterText(find.byType(TextFormField).at(1), 'incorrecta');
      await tocarYEsperar(tester, find.text('Ingresar'));
      expect(find.text('Usuario o contraseña incorrectos.'), findsOneWidget);
      expect(sesion.autenticado, isFalse);
      final clave = tester.widget<EditableText>(find.byType(EditableText).at(1));
      expect(clave.controller.text, isEmpty);
    });

    testWidgets('al autenticarse vuelve al destino solicitado', (tester) async {
      await montarApp(tester);
      irA(tester, Rutas.tribunal);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'presidente');
      await tester.enterText(find.byType(TextFormField).at(1), 'Clave123');
      await tocarYEsperar(tester, find.text('Ingresar'));
      expect(find.byType(PantallaTribunal), findsOneWidget);
    });

    testWidgets('sin conexión informa y no autentica', (tester) async {
      final sesion = await montarApp(tester);
      tec.sinConexion = true;
      irA(tester, Rutas.iniciarSesion);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'presidente');
      await tester.enterText(find.byType(TextFormField).at(1), 'Clave123');
      await tocarYEsperar(tester, find.text('Ingresar'));
      expect(find.textContaining('No se pudo conectar'), findsOneWidget);
      expect(sesion.autenticado, isFalse);
    });
  });

  group('Cambio de clave obligatorio', () {
    testWidgets('usuario no permanente solo puede cambiar su clave', (tester) async {
      await montarApp(tester, usuario: 'nuevo', clave: 'Temporal1');
      expect(find.text('Guardar contraseña'), findsOneWidget);
      irA(tester, Rutas.tribunal);
      await tester.pumpAndSettle();
      expect(find.text('Guardar contraseña'), findsOneWidget);
    });

    testWidgets('valida la política antes de enviar', (tester) async {
      await montarApp(tester, usuario: 'nuevo', clave: 'Temporal1');
      await tester.enterText(find.byType(TextFormField).at(0), 'Temporal1');
      await tester.enterText(find.byType(TextFormField).at(1), 'corta');
      await tester.enterText(find.byType(TextFormField).at(2), 'corta');
      await tester.ensureVisible(find.text('Guardar contraseña'));
      await tester.tap(find.text('Guardar contraseña'));
      await tester.pumpAndSettle();
      expect(find.text('La contraseña no cumple los requisitos.'), findsOneWidget);
      expect(tec.rutas, isNot(contains('/auth/cambiar-clave')));
    });

    testWidgets('tras cambiarla entra al módulo', (tester) async {
      await montarApp(tester, usuario: 'nuevo', clave: 'Temporal1');
      await tester.enterText(find.byType(TextFormField).at(0), 'Temporal1');
      await tester.enterText(find.byType(TextFormField).at(1), 'Nueva1234');
      await tester.enterText(find.byType(TextFormField).at(2), 'Nueva1234');
      await tocarYEsperar(tester, find.text('Guardar contraseña'));
      expect(find.byType(PantallaTribunal), findsOneWidget);
    });

    testWidgets('cancelar cierra la sesión', (tester) async {
      final sesion = await montarApp(tester, usuario: 'nuevo', clave: 'Temporal1');
      await tocarYEsperar(tester, find.text('Cancelar y cerrar sesión'));
      expect(sesion.autenticado, isFalse);
      expect(find.text('Iniciar sesión'), findsOneWidget);
    });
  });

  group('Entorno', () {
    test('acepta la URL https de TEC', () {
      expect(Entorno.desdeUrl('https://tribunal.conpociiech.org/api/v1').apiBaseUrl.host,
          'tribunal.conpociiech.org');
    });

    test('rechaza http y URLs relativas', () {
      expect(() => Entorno.desdeUrl('http://tribunal.conpociiech.org/api/v1'), throwsArgumentError);
      expect(() => Entorno.desdeUrl('/api/v1'), throwsArgumentError);
    });
  });
}

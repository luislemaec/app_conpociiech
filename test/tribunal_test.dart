import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:app_conpociiech/app.dart';
import 'package:app_conpociiech/core/config/entorno.dart';
import 'package:app_conpociiech/core/router/app_router.dart';
import 'package:app_conpociiech/core/sesion/roles.dart';
import 'package:app_conpociiech/features/tribunal/api_tribunal.dart';

import 'tec_simulado.dart';

late TecSimulado tec;

Future<void> montar(WidgetTester tester, String usuario) async {
  final sesion = tec.crearSesion();
  await tester.runAsync(() => sesion.iniciarSesion(usuario, 'Clave123'));
  await tester.pumpWidget(
      AppConpociiech(entorno: Entorno.desdeUrl(Entorno.urlPorDefecto), sesion: sesion, cliente: tec.api));
  await tester.pumpAndSettle();
}

/// Navega y espera las respuestas del servidor simulado.
Future<void> ir(WidgetTester tester, String ruta) async {
  GoRouter.of(tester.element(find.byType(Scaffold).first)).go(ruta);
  await tester.pumpAndSettle();
  await esperar(tester);
}

Future<void> esperar(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pumpAndSettle();
  }
}

void main() {
  setUp(() {
    tec = TecSimulado()
      ..usuarios['presidente'] = UsuarioSimulado(clave: 'Clave123', roles: [RolTec.presidenteMesa])
      ..usuarios['iglesia'] = UsuarioSimulado(clave: 'Clave123', roles: [RolTec.iglesiaAdmin])
      ..usuarios['tribunal'] = UsuarioSimulado(clave: 'Clave123', roles: [RolTec.tribunal])
      ..usuarios['varios'] = UsuarioSimulado(clave: 'Clave123', roles: [RolTec.iglesiaAdmin, RolTec.presidenteMesa])
      ..usuarios['tecnico'] = UsuarioSimulado(clave: 'Clave123', roles: [RolTec.tecnico]);
  });

  group('Panel del módulo según roles', () {
    testWidgets('Presidente solo ve «Mi mesa»', (tester) async {
      await montar(tester, 'presidente');
      await ir(tester, Rutas.tribunal);
      expect(find.text('Mi mesa'), findsOneWidget);
      expect(find.text('Mi iglesia'), findsNothing);
      expect(find.text('Proceso electoral'), findsNothing);
    });

    testWidgets('varios roles: unión de secciones', (tester) async {
      await montar(tester, 'varios');
      await ir(tester, Rutas.tribunal);
      expect(find.text('Mi mesa'), findsOneWidget);
      expect(find.text('Mi iglesia'), findsOneWidget);
      expect(find.text('Proceso electoral'), findsNothing);
    });

    testWidgets('una sección ajena redirige al panel', (tester) async {
      await montar(tester, 'presidente');
      await ir(tester, Rutas.proceso);
      expect(find.text('Mi mesa'), findsOneWidget);
      expect(tec.consultas.where((u) => u.path.contains('/proceso')), isEmpty);
    });

    testWidgets('roles sin funciones en V1 no entran al módulo', (tester) async {
      await montar(tester, 'tecnico');
      await ir(tester, Rutas.tribunal);
      expect(find.text('Iniciar sesión'), findsNothing);
      expect(find.text('Mi mesa'), findsNothing);
      expect(find.text('Tribunal Electoral'), findsNothing);
    });
  });

  group('Presidente de mesa', () {
    testWidgets('muestra la mesa, la junta y oculta resultados si no está cerrada', (tester) async {
      await montar(tester, 'presidente');
      await ir(tester, Rutas.miMesa);
      expect(find.text('MESA 7'), findsOneWidget);
      expect(find.text('Abierta'), findsOneWidget);
      expect(find.text('Pérez Ana'), findsOneWidget);
      expect(find.text('Los resultados se muestran cuando la mesa está cerrada.'), findsOneWidget);
    });

    testWidgets('con la mesa cerrada muestra resultados', (tester) async {
      tec.estadoMesa = 'CERRADO';
      await montar(tester, 'presidente');
      await ir(tester, Rutas.miMesa);
      expect(find.text('Cerrada'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('LISTA 1'), 200);
      expect(find.text('LISTA 1'), findsOneWidget);
    });

    testWidgets('padrón con búsqueda local', (tester) async {
      await montar(tester, 'presidente');
      await ir(tester, Rutas.padronMesa);
      expect(find.text('3 de 3 electores'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'norte');
      await tester.pumpAndSettle();
      expect(find.text('Bravo Juan'), findsOneWidget);
      expect(find.text('Andrade Rosa'), findsNothing);
    });
  });

  group('IglesiaAdmin', () {
    Uri ultimaConsultaMiembros() => tec.consultas.lastWhere((u) => u.path.endsWith('/miembros'));

    testWidgets('muestra la iglesia y su resumen', (tester) async {
      await montar(tester, 'iglesia');
      await ir(tester, Rutas.miIglesia);
      expect(find.text('Iglesia Central'), findsOneWidget);
      expect(find.text('Habilitados para participar'), findsOneWidget);
      expect(find.text('23'), findsOneWidget);
    });

    testWidgets('miembros por páginas y filtro de habilitación', (tester) async {
      await montar(tester, 'iglesia');
      await ir(tester, Rutas.miembrosIglesia);
      expect(find.text('45 miembros'), findsOneWidget);
      expect(ultimaConsultaMiembros().queryParameters['pagina'], '0');

      await tester.drag(find.byType(ListView), const Offset(0, -3000));
      await esperar(tester);
      expect(ultimaConsultaMiembros().queryParameters['pagina'], '1');

      await tester.tap(find.text('No habilitados'));
      await esperar(tester);
      expect(ultimaConsultaMiembros().queryParameters['habilitado'], 'false');
      expect(find.text('22 miembros'), findsOneWidget);
    });
  });

  group('Tribunal / Administrador', () {
    testWidgets('resumen del proceso', (tester) async {
      await montar(tester, 'tribunal');
      await ir(tester, Rutas.proceso);
      expect(find.text('Elecciones 2026'), findsOneWidget);
      expect(find.text('1 (50 %)'), findsOneWidget);
    });

    testWidgets('avance de mesas con filtro por estado', (tester) async {
      await montar(tester, 'tribunal');
      await ir(tester, Rutas.avanceMesas);
      expect(find.text('2 de 2 mesas'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<String?>).at(2));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cerrada').last);
      await tester.pumpAndSettle();
      expect(find.text('1 de 2 mesas'), findsOneWidget);
      expect(find.text('MESA 8'), findsOneWidget);
    });

    testWidgets('resultados consolidados', (tester) async {
      await montar(tester, 'tribunal');
      await ir(tester, Rutas.resultados);
      expect(find.text('Lista 1 Unidad'), findsOneWidget);
      expect(find.text('200 · 69.57 %'), findsOneWidget);
    });
  });

  group('Errores de TEC', () {
    test('un rol no autorizado recibe el mensaje de TEC', () async {
      final sesion = tec.crearSesion();
      await sesion.iniciarSesion('presidente', 'Clave123');
      await expectLater(ApiTribunal(tec.api, sesion).iglesia(), throwsA(errorApi('SIN_PERMISO')));
    });

    test('la URL lleva los parámetros de consulta', () async {
      final sesion = tec.crearSesion();
      await sesion.iniciarSesion('iglesia', 'Clave123');
      await ApiTribunal(tec.api, sesion).miembros(busqueda: ' ana ', habilitado: true, pagina: 2);
      final url = tec.consultas.last;
      expect(url.path, '/api/v1/tribunal/iglesia/miembros');
      expect(url.queryParameters, {'busqueda': 'ana', 'habilitado': 'true', 'pagina': '2', 'tamano': '30'});
    });
  });
}

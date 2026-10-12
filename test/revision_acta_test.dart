import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:app_conpociiech/app.dart';
import 'package:app_conpociiech/core/config/entorno.dart';
import 'package:app_conpociiech/core/router/app_router.dart';
import 'package:app_conpociiech/core/sesion/roles.dart';
import 'package:app_conpociiech/features/tribunal/api_tribunal.dart';
import 'package:app_conpociiech/features/tribunal/proceso/pantalla_detalle_mesa.dart';

import 'tec_simulado.dart';

late TecSimulado tec;

Future<void> montar(WidgetTester tester, String usuario, String ruta) async {
  final sesion = tec.crearSesion();
  await tester.runAsync(() => sesion.iniciarSesion(usuario, 'Clave123'));
  await tester.pumpWidget(
      AppConpociiech(entorno: Entorno.desdeUrl(Entorno.urlPorDefecto), sesion: sesion, cliente: tec.api));
  await tester.pumpAndSettle();
  GoRouter.of(tester.element(find.byType(Scaffold).first)).go(ruta);
  await esperar(tester);
}

Future<void> esperar(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pumpAndSettle();
  }
}

Future<void> tocar(WidgetTester tester, String texto) async {
  final boton = find.text(texto);
  await tester.scrollUntilVisible(boton, 200, scrollable: find.byType(Scrollable).first);
  await tester.ensureVisible(boton);
  await tester.pumpAndSettle();
  await tester.tap(boton);
  await tester.pumpAndSettle();
}

Finder enDialogo(Finder f) => find.descendant(of: find.byType(AlertDialog), matching: f);

void main() {
  setUp(() {
    tec = TecSimulado()
      ..usuarios['admin'] = UsuarioSimulado(clave: 'Clave123', roles: [RolTec.administrador])
      ..usuarios['tribunal'] = UsuarioSimulado(clave: 'Clave123', roles: [RolTec.tribunal])
      ..usuarios['presidente'] = UsuarioSimulado(clave: 'Clave123', roles: [RolTec.presidenteMesa]);
  });

  testWidgets('el resumen muestra las alertas del proceso y llevan al avance de mesas', (tester) async {
    await montar(tester, 'admin', Rutas.proceso);
    expect(find.text('Mesas con escrutinio observado'), findsOneWidget);
    expect(find.text('Mesas cerradas sin acta física cargada'), findsOneWidget);
    await tester.tap(find.text('Mesas con escrutinio observado'));
    await esperar(tester);
    expect(find.text('2 de 2 mesas'), findsOneWidget);
  });

  testWidgets('desde el avance de mesas se abre el detalle', (tester) async {
    await montar(tester, 'admin', Rutas.avanceMesas);
    await tester.tap(find.text('MESA 8'));
    await esperar(tester);
    expect(find.byType(PantallaDetalleMesa), findsOneWidget);
    expect(find.text('Ortiz Carla'), findsOneWidget);
    expect(find.text('0 (cuadrado)'), findsOneWidget);
  });

  testWidgets('validar exige confirmar el cotejo y deja el acta como dato oficial', (tester) async {
    await montar(tester, 'tribunal', Rutas.detalleMesa(8));
    await tocar(tester, 'Validar como dato oficial');
    final validar = enDialogo(find.widgetWithText(FilledButton, 'Validar'));
    expect(tester.widget<FilledButton>(validar).onPressed, isNull, reason: 'sin cotejo no se valida');
    await tester.tap(enDialogo(find.byType(CheckboxListTile)));
    await tester.pumpAndSettle();
    await tester.tap(validar);
    await esperar(tester);
    expect(tec.revisionMesa8, 'VALIDADA');
    expect(find.text('Validada: dato oficial'), findsOneWidget);
    expect(find.text('Validar como dato oficial'), findsNothing);
  });

  testWidgets('observar exige motivo y devuelve la mesa al Presidente', (tester) async {
    await montar(tester, 'tribunal', Rutas.detalleMesa(8));
    await tocar(tester, 'Observar');
    final observar = enDialogo(find.widgetWithText(FilledButton, 'Observar'));
    expect(tester.widget<FilledButton>(observar).onPressed, isNull, reason: 'sin motivo no se observa');
    await tester.enterText(enDialogo(find.byType(TextField)), 'La firma del secretario no es legible');
    await tester.pumpAndSettle();
    await tester.tap(observar);
    await esperar(tester);
    expect(tec.revisionMesa8, 'OBSERVADA');
    expect(tec.estadoMesa8, 'REABIERTO');
    expect(tec.observacionMesa8, 'La firma del secretario no es legible');
    expect(find.text('Observar'), findsNothing, reason: 'reabierta, ya no se revisa');
  });

  testWidgets('el Administrador consulta el acta pero no la revisa', (tester) async {
    await montar(tester, 'admin', Rutas.detalleMesa(8));
    await tester.scrollUntilVisible(find.text('Ver foto del acta'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('Ver foto del acta'), findsOneWidget);
    expect(find.text('Validar como dato oficial'), findsNothing);
    expect(find.text('Observar'), findsNothing);
    expect(find.text('Rechazar'), findsNothing);
  });

  test('si el Administrador intenta validar, TEC lo rechaza', () async {
    final sesion = tec.crearSesion();
    await sesion.iniciarSesion('admin', 'Clave123');
    await expectLater(ApiTribunal(tec.api, sesion).validarActa(8), throwsA(errorApi('SIN_PERMISO')));
    expect(tec.revisionMesa8, 'PENDIENTE_REVISION');
  });

  testWidgets('ver la foto descarga el acta de TEC', (tester) async {
    await montar(tester, 'admin', Rutas.detalleMesa(8));
    await tocar(tester, 'Ver foto del acta');
    await esperar(tester);
    expect(find.text('Acta · MESA 8'), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(tec.rutas, contains('/tribunal/proceso/mesas/8/acta-fisica'));
  });

  testWidgets('un Presidente no puede abrir el detalle de otra mesa', (tester) async {
    await montar(tester, 'presidente', Rutas.detalleMesa(8));
    expect(find.byType(PantallaDetalleMesa), findsNothing);
    expect(tec.rutas.where((r) => r.startsWith('/tribunal/proceso')), isEmpty);
  });

  test('la foto llega como bytes y los errores siguen el contrato', () async {
    final sesion = tec.crearSesion();
    await sesion.iniciarSesion('admin', 'Clave123');
    final api = ApiTribunal(tec.api, sesion);
    expect(await api.fotoActa(8), [0xFF, 0xD8, 0xFF, 0xE0]);
    await expectLater(api.detalleMesa(99), throwsA(errorApi('MESA_NO_ENCONTRADA')));
  });
}

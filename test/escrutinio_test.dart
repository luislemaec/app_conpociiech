import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:app_conpociiech/app.dart';
import 'package:app_conpociiech/core/config/entorno.dart';
import 'package:app_conpociiech/core/router/app_router.dart';
import 'package:app_conpociiech/core/sesion/roles.dart';
import 'package:app_conpociiech/core/sesion/sesion_controller.dart';
import 'package:app_conpociiech/features/tribunal/api_tribunal.dart';
import 'package:app_conpociiech/features/tribunal/presidente/pantalla_escrutinio.dart';

import 'tec_simulado.dart';

late TecSimulado tec;

Future<void> montar(WidgetTester tester) async {
  pantallaAlta(tester);
  final sesion = tec.crearSesion();
  await tester.runAsync(() => sesion.iniciarSesion('presidente', 'Clave123'));
  await tester.pumpWidget(
    AppConpociiech(
      entorno: Entorno.desdeUrl(Entorno.urlPorDefecto),
      sesion: sesion,
      cliente: tec.api,
    ),
  );
  await tester.pumpAndSettle();
  GoRouter.of(tester.element(find.byType(Scaffold).first)).go(Rutas.escrutinio);
  await esperar(tester);
}

/// Pantalla alta: las listas construyen solo lo visible y el flujo ocupa varias secciones.
void pantallaAlta(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(900, 4000)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Monta solo la pantalla de escrutinio con un selector de foto simulado.
Future<void> montarPantalla(WidgetTester tester, SelectorFoto selector) async {
  pantallaAlta(tester);
  final sesion = tec.crearSesion();
  await tester.runAsync(() => sesion.iniciarSesion('presidente', 'Clave123'));
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SesionController>.value(value: sesion),
        Provider<ApiTribunal>.value(value: ApiTribunal(tec.api, sesion)),
      ],
      child: MaterialApp(home: PantallaEscrutinio(selectorFoto: selector)),
    ),
  );
  await esperar(tester);
}

Future<void> esperar(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();
  }
}

Future<void> tocar(WidgetTester tester, Finder boton) async {
  await tester.scrollUntilVisible(
    boton,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(boton);
  await tester.pumpAndSettle();
  await tester.tap(boton);
  await tester.pumpAndSettle();
}

/// Confirma el diálogo pulsando su botón principal.
Future<void> confirmar(WidgetTester tester, String accion) async {
  await tester.tap(
    find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, accion),
    ),
  );
  await esperar(tester);
}

Future<void> escribirConteo(
  WidgetTester tester,
  int lista,
  int blancos,
  int papeletas,
) async {
  for (final (id, valor) in [(1, lista), (2, blancos), (3, papeletas)]) {
    final campo = find.byKey(ValueKey('categoria-$id'));
    await tester.ensureVisible(campo);
    await tester.enterText(campo, '$valor');
  }
  await tester.pumpAndSettle();
}

ButtonStyleButton boton(WidgetTester tester, String texto) =>
    tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text(texto),
        matching: find.bySubtype<ButtonStyleButton>(),
      ),
    );

void main() {
  setUp(() {
    tec = TecSimulado()
      ..usuarios['presidente'] = UsuarioSimulado(
        clave: 'Clave123',
        roles: [RolTec.presidenteMesa],
      )
      ..usuarios['iglesia'] = UsuarioSimulado(
        clave: 'Clave123',
        roles: [RolTec.iglesiaAdmin],
      );
  });

  testWidgets('con la apertura bloqueada muestra el motivo de TEC', (
    tester,
  ) async {
    tec.bloqueoApertura = 'La junta receptora del voto está incompleta.';
    await montar(tester);
    expect(
      find.text('La junta receptora del voto está incompleta.'),
      findsOneWidget,
    );
    expect(find.text('Registrar apertura'), findsNothing);
  });

  testWidgets('flujo completo: apertura, conteo, acta física, cierre', (
    tester,
  ) async {
    await montarPantalla(tester, (_) async => [0xFF, 0xD8, 0xFF, 0xE0, 1]);
    expect(find.text('1. Apertura · Pendiente'), findsWidgets);
    expect(find.text('Por abrir'), findsOneWidget);

    await tocar(tester, find.text('Registrar apertura'));
    await confirmar(tester, 'Registrar apertura');
    expect(tec.estadoActa, 'ABIERTO');
    expect(find.text('Abierta'), findsOneWidget);

    await escribirConteo(tester, 5, 3, 2);
    expect(find.text('0 (cuadrado)'), findsOneWidget);
    expect(
      boton(tester, 'Cerrar mesa').onPressed,
      isNull,
      reason: 'primero se guarda el conteo',
    );

    await tocar(tester, find.text('Guardar conteo'));
    await esperar(tester);
    expect(tec.estadoActa, 'CONTEO_REGISTRADO');
    expect(tec.votosActa, {1: 5, 2: 3, 3: 2});
    expect(
      boton(tester, 'Cerrar mesa').onPressed,
      isNull,
      reason: 'sin acta física no se puede cerrar',
    );
    expect(find.text('3. Acta física · Pendiente de carga'), findsWidgets);

    await tocar(tester, find.text('Tomar foto del acta'));
    await esperar(tester);
    expect(tec.actaFisica?['estadoRevision'], 'PENDIENTE_REVISION');
    expect(find.text('4. Cierre · Pendiente'), findsWidgets);
    expect(boton(tester, 'Cerrar mesa').onPressed, isNotNull);

    await tocar(tester, find.text('Cerrar mesa'));
    expect(find.textContaining('Las papeletas cuadran'), findsOneWidget);
    await confirmar(tester, 'Cerrar mesa');
    expect(tec.estadoActa, 'CERRADO');
    expect(find.text('5. Validación · Pendiente'), findsWidgets);
    expect(find.text('Cerrar mesa'), findsNothing);
    expect(
      find.byKey(const ValueKey('categoria-1')).evaluate().isEmpty ||
          tester
                  .widget<TextField>(find.byKey(const ValueKey('categoria-1')))
                  .enabled ==
              false,
      isTrue,
      reason: 'cerrada, el conteo ya no se edita',
    );
  });

  testWidgets('editar el conteo vuelve a exigir guardarlo antes de cerrar', (
    tester,
  ) async {
    tec
      ..estadoActa = 'CONTEO_REGISTRADO'
      ..votosActa.addAll({1: 5, 2: 3, 3: 2})
      ..actaFisica = {'version': 1, 'estadoRevision': 'PENDIENTE_REVISION'};
    await montar(tester);
    expect(boton(tester, 'Cerrar mesa').onPressed, isNotNull);
    await escribirConteo(tester, 6, 3, 2);
    expect(boton(tester, 'Cerrar mesa').onPressed, isNull);
    expect(
      find.text('Guarde el conteo antes de cerrar la mesa.'),
      findsOneWidget,
    );
    expect(find.text('-1 (no cuadra)'), findsOneWidget);
  });

  testWidgets('con el acta devuelta por el Tribunal se exige una nueva versión', (
    tester,
  ) async {
    tec
      ..estadoActa = 'REABIERTO'
      ..votosActa.addAll({1: 5, 2: 3, 3: 2})
      ..actaFisica = {
        'version': 1,
        'estadoRevision': 'OBSERVADA',
        'observacion': 'Firma ilegible',
      };
    await montarPantalla(tester, (_) async => [0xFF, 0xD8, 0xFF, 0xE0, 1]);
    expect(find.text('Escrutinio reabierto'), findsWidgets);
    expect(boton(tester, 'Cerrar mesa').onPressed, isNull);
    expect(
      find.text(
        'El Tribunal devolvió el acta física: envíe una nueva versión para cerrar.',
      ),
      findsOneWidget,
    );

    await tocar(tester, find.text('Enviar otra foto'));
    await esperar(tester);
    expect(tec.actaFisica?['version'], 2);
    expect(boton(tester, 'Cerrar mesa').onPressed, isNotNull);
  });

  testWidgets('un campo vacío impide guardar', (tester) async {
    tec.estadoActa = 'ABIERTO';
    await montar(tester);
    await tester.enterText(find.byKey(const ValueKey('categoria-1')), '');
    await tester.pumpAndSettle();
    expect(find.text('Ingrese un número en cada categoría.'), findsOneWidget);
    expect(boton(tester, 'Guardar conteo').onPressed, isNull);
  });

  testWidgets(
    'la foto del acta se envía como JPEG y queda pendiente de revisión',
    (tester) async {
      tec.estadoActa = 'CERRADO';
      final sesion = tec.crearSesion();
      await tester.runAsync(
        () => sesion.iniciarSesion('presidente', 'Clave123'),
      );
      var foto = <int>[0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3];
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SesionController>.value(value: sesion),
            Provider<ApiTribunal>.value(value: ApiTribunal(tec.api, sesion)),
          ],
          child: MaterialApp(
            home: PantallaEscrutinio(selectorFoto: (_) async => foto),
          ),
        ),
      );
      await esperar(tester);

      await tocar(tester, find.text('Tomar foto del acta'));
      await esperar(tester);
      expect(tec.ultimoTipo, 'image/jpeg');
      expect(tec.ultimoBinario, foto);
      expect(find.text('Pendiente de revisión del Tribunal'), findsOneWidget);

      foto = <int>[0x89, 0x50, 0x4E, 0x47];
      await tocar(tester, find.text('Enviar otra foto'));
      await esperar(tester);
      expect(find.text('La foto debe estar en formato JPEG.'), findsOneWidget);
      expect(tec.actaFisica?['version'], 1, reason: 'el PNG no llega a TEC');
    },
  );

  test('solo el Presidente de mesa accede al escrutinio', () async {
    final sesion = tec.crearSesion();
    await sesion.iniciarSesion('iglesia', 'Clave123');
    await expectLater(
      ApiTribunal(tec.api, sesion).acta(),
      throwsA(errorApi('SIN_PERMISO')),
    );
  });

  test('el conteo viaja con todas las categorías', () async {
    tec.estadoActa = 'ABIERTO';
    final sesion = tec.crearSesion();
    await sesion.iniciarSesion('presidente', 'Clave123');
    final acta = await ApiTribunal(
      tec.api,
      sesion,
    ).guardarConteo({1: 4, 2: 1, 3: 3});
    expect(acta.estado, 'EN_CONTEO');
    expect(acta.cuadre, 2);
    expect(acta.puedeCerrar, isFalse, reason: 'falta el acta física');
    expect(acta.puedeSubirActaFisica, isTrue);
    expect(acta.fase?.fase, 'CONTEO');
  });
}

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:app_conpociiech/app.dart';
import 'package:app_conpociiech/core/config/entorno.dart';
import 'package:app_conpociiech/core/push/proveedor_push.dart';
import 'package:app_conpociiech/core/sesion/roles.dart';
import 'package:app_conpociiech/core/sesion/sesion_controller.dart';
import 'package:app_conpociiech/features/tribunal/pantalla_tribunal.dart';
import 'package:app_conpociiech/features/tribunal/presidente/pantalla_escrutinio.dart';

import 'tec_simulado.dart';

/// Proveedor de avisos falso: el token y los avisos los controla la prueba.
class ProveedorPushFalso implements ProveedorPush {
  String? token = 'token-dispositivo-0001-abcdefghij';
  final renovado = StreamController<String>.broadcast();
  final recibido = StreamController<AvisoPush>.broadcast();
  final abierto = StreamController<AvisoPush>.broadcast();

  @override
  Future<String?> obtenerToken() async => token;

  @override
  Stream<String> get tokenRenovado => renovado.stream;

  @override
  Stream<AvisoPush> get avisoRecibido => recibido.stream;

  @override
  Stream<AvisoPush> get avisoAbierto => abierto.stream;

  @override
  String get plataforma => 'android';
}

late TecSimulado tec;
late ProveedorPushFalso push;

Future<SesionController> montar(
  WidgetTester tester, {
  String? usuario,
  String clave = 'Clave123',
}) async {
  final sesion = tec.crearSesion();
  if (usuario != null)
    await tester.runAsync(() => sesion.iniciarSesion(usuario, clave));
  await tester.pumpWidget(
    AppConpociiech(
      entorno: Entorno.desdeUrl(Entorno.urlPorDefecto),
      sesion: sesion,
      cliente: tec.api,
      proveedorPush: push,
    ),
  );
  await esperar(tester);
  return sesion;
}

Future<void> esperar(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();
  }
}

void main() {
  setUp(() {
    tec = TecSimulado()
      ..usuarios['presidente'] = UsuarioSimulado(
        clave: 'Clave123',
        roles: [RolTec.presidenteMesa],
      )
      ..usuarios['nuevo'] = UsuarioSimulado(
        clave: 'Temporal1',
        roles: [RolTec.tribunal],
        permanente: false,
      );
    push = ProveedorPushFalso();
  });

  testWidgets('con sesión completa registra el dispositivo en TEC', (
    tester,
  ) async {
    await montar(tester, usuario: 'presidente');
    expect(tec.dispositivos, {push.token: 'presidente'});
  });

  testWidgets('sin sesión o con cambio de clave obligatorio no registra nada', (
    tester,
  ) async {
    await montar(tester);
    expect(tec.dispositivos, isEmpty);
    await montar(tester, usuario: 'nuevo', clave: 'Temporal1');
    expect(tec.dispositivos, isEmpty);
  });

  testWidgets('sin permiso de notificaciones no registra nada', (tester) async {
    push.token = null;
    await montar(tester, usuario: 'presidente');
    expect(tec.dispositivos, isEmpty);
  });

  testWidgets('al renovarse el token lo vuelve a registrar', (tester) async {
    await montar(tester, usuario: 'presidente');
    push.renovado.add('token-dispositivo-0002-abcdefghij');
    await esperar(tester);
    expect(tec.dispositivos['token-dispositivo-0002-abcdefghij'], 'presidente');
  });

  testWidgets('al cerrar sesión da de baja el dispositivo antes de revocar', (
    tester,
  ) async {
    final sesion = await montar(tester, usuario: 'presidente');
    await tester.runAsync(sesion.cerrar);
    await esperar(tester);
    expect(tec.dispositivos, isEmpty);
    expect(tec.rutas.sublist(tec.rutas.length - 2), [
      '/dispositivos/baja',
      '/auth/logout',
    ]);
  });

  testWidgets(
    'un aviso con la App abierta se muestra y «Ver» abre su pantalla',
    (tester) async {
      await montar(tester, usuario: 'presidente');
      push.recibido.add(
        const AvisoPush(
          titulo: 'Revisión del acta',
          cuerpo: 'El Tribunal validó el acta física de su mesa.',
          ruta: '/tribunal/mesa/escrutinio',
        ),
      );
      await esperar(tester);
      expect(
        find.text(
          'Revisión del acta: El Tribunal validó el acta física de su mesa.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Ver'));
      await esperar(tester);
      expect(find.byType(PantallaEscrutinio), findsOneWidget);
    },
  );

  testWidgets(
    'tocar un aviso con una ruta desconocida lleva al módulo, no a una ruta arbitraria',
    (tester) async {
      await montar(tester, usuario: 'presidente');
      push.abierto.add(const AvisoPush(ruta: '/cualquier/cosa'));
      await esperar(tester);
      expect(find.byType(PantallaTribunal), findsOneWidget);
    },
  );

  testWidgets('tocar un aviso sin sesión pide iniciar sesión primero', (
    tester,
  ) async {
    await montar(tester);
    push.abierto.add(const AvisoPush(ruta: '/tribunal/mesa/escrutinio'));
    await esperar(tester);
    expect(find.text('Ingresar'), findsOneWidget);
    expect(find.byType(PantallaEscrutinio), findsNothing);
  });
}

import 'package:flutter_test/flutter_test.dart';

import 'package:app_conpociiech/core/api/cliente_api.dart';
import 'package:app_conpociiech/core/sesion/almacen_tokens.dart';
import 'package:app_conpociiech/core/sesion/roles.dart';
import 'package:app_conpociiech/core/sesion/sesion_controller.dart';

import 'tec_simulado.dart';

void main() {
  late TecSimulado tec;
  late DateTime ahora;
  DateTime reloj() => ahora;

  setUp(() {
    ahora = DateTime(2026, 10, 8, 9);
    tec = TecSimulado()
      ..usuarios['presidente'] = UsuarioSimulado(clave: 'Clave123', roles: [RolTec.presidenteMesa])
      ..usuarios['nuevo'] = UsuarioSimulado(clave: 'Temporal1', roles: [RolTec.tribunal], permanente: false)
      ..usuarios['varios'] = UsuarioSimulado(clave: 'Clave123', roles: ['Usuario', RolTec.iglesiaAdmin]);
  });

  test('inicia sesión, guarda solo el refresh y expone el perfil', () async {
    final almacen = AlmacenTokensMemoria();
    final sesion = tec.crearSesion(almacen: almacen, reloj: reloj);
    await sesion.iniciarSesion(' presidente ', 'Clave123');
    expect(sesion.autenticado, isTrue);
    expect(sesion.nombreUsuario, 'Persona presidente');
    expect(sesion.puedeAccederTribunal, isTrue);
    expect(almacen.refresh, 'refresh-1');
  });

  test('credenciales incorrectas: error de TEC y sin sesión', () async {
    final sesion = tec.crearSesion(reloj: reloj);
    await expectLater(sesion.iniciarSesion('presidente', 'mala'), throwsA(errorApi('CREDENCIALES_INVALIDAS')));
    expect(sesion.autenticado, isFalse);
  });

  test('sin red lanza SinConexion', () async {
    tec.sinConexion = true;
    final sesion = tec.crearSesion(reloj: reloj);
    await expectLater(sesion.iniciarSesion('presidente', 'Clave123'), throwsA(isA<SinConexion>()));
  });

  test('varios roles: unión de permisos', () async {
    final sesion = tec.crearSesion(reloj: reloj);
    await sesion.iniciarSesion('varios', 'Clave123');
    expect(sesion.puedeAccederTribunal, isTrue);
  });

  test('token de acceso vencido: renueva antes de la petición y rota el refresh', () async {
    final almacen = AlmacenTokensMemoria();
    final sesion = tec.crearSesion(almacen: almacen, reloj: reloj);
    await sesion.iniciarSesion('presidente', 'Clave123');
    ahora = ahora.add(const Duration(minutes: 5));
    final perfil = await sesion.autenticada((token) async => token);
    expect(perfil, 'acceso-2');
    expect(almacen.refresh, 'refresh-2');
    expect(tec.rutas, contains('/auth/refresh'));
  });

  test('ante un 401 renueva una vez y reintenta', () async {
    final sesion = tec.crearSesion(reloj: reloj);
    await sesion.iniciarSesion('presidente', 'Clave123');
    tec.vencerAccesos();
    final usados = <String>[];
    await sesion.autenticada((token) async {
      usados.add(token);
      if (token == 'acceso-1') throw const ErrorApi(401, 'SESION_INVALIDA', '');
      return token;
    });
    expect(usados, ['acceso-1', 'acceso-2']);
  });

  test('renovaciones simultáneas usan el refresh una sola vez', () async {
    final sesion = tec.crearSesion(reloj: reloj);
    await sesion.iniciarSesion('presidente', 'Clave123');
    ahora = ahora.add(const Duration(minutes: 5));
    await Future.wait([
      sesion.autenticada((t) async => t),
      sesion.autenticada((t) async => t),
    ]);
    expect(tec.rutas.where((r) => r == '/auth/refresh'), hasLength(1));
    expect(sesion.autenticado, isTrue);
  });

  test('refresh rechazado por TEC: cierra la sesión con aviso', () async {
    final almacen = AlmacenTokensMemoria();
    final sesion = tec.crearSesion(almacen: almacen, reloj: reloj);
    await sesion.iniciarSesion('presidente', 'Clave123');
    // Cambio de clave desde otro dispositivo: TEC revoca todas las sesiones del usuario.
    final otra = tec.crearSesion(reloj: reloj);
    await otra.iniciarSesion('presidente', 'Clave123');
    await otra.cambiarClave('Clave123', 'Nueva1234');
    ahora = ahora.add(const Duration(minutes: 6));
    await expectLater(sesion.autenticada((t) async => t), throwsA(errorApi('SESION_INVALIDA')));
    expect(sesion.autenticado, isFalse);
    expect(sesion.consumirAviso(), SesionController.avisoExpirada);
    expect(almacen.refresh, isNull);
  });

  test('15 minutos sin actividad cierran la sesión', () async {
    final sesion = tec.crearSesion(reloj: reloj);
    await sesion.iniciarSesion('presidente', 'Clave123');
    ahora = ahora.add(const Duration(minutes: 15));
    sesion.registrarActividad();
    expect(sesion.autenticado, isFalse);
    expect(sesion.consumirAviso(), SesionController.avisoInactividad);
    expect(sesion.consumirAviso(), isNull);
  });

  test('con actividad la sesión sigue viva y se renueva en TEC', () async {
    final sesion = tec.crearSesion(reloj: reloj);
    await sesion.iniciarSesion('presidente', 'Clave123');
    for (var i = 0; i < 4; i++) {
      ahora = ahora.add(const Duration(minutes: 6));
      sesion.registrarActividad();
      await pumpEventQueue();
    }
    expect(sesion.autenticado, isTrue);
    expect(tec.rutas.where((r) => r == '/auth/refresh'), isNotEmpty);
  });

  test('usuario no permanente: solo cambio de clave, luego sesión completa', () async {
    final sesion = tec.crearSesion(reloj: reloj);
    await sesion.iniciarSesion('nuevo', 'Temporal1');
    expect(sesion.cambioClaveObligatorio, isTrue);
    expect(sesion.puedeAccederTribunal, isFalse);
    await expectLater(sesion.cambiarClave('mala', 'Nueva1234'), throwsA(errorApi('CLAVE_INCORRECTA')));
    await sesion.cambiarClave('Temporal1', 'Nueva1234');
    expect(sesion.cambioClaveObligatorio, isFalse);
    expect(sesion.puedeAccederTribunal, isTrue);
  });

  test('restaurar: recupera la sesión guardada o borra un refresh inválido', () async {
    final almacen = AlmacenTokensMemoria();
    await tec.crearSesion(almacen: almacen, reloj: reloj).iniciarSesion('presidente', 'Clave123');

    final restaurada = tec.crearSesion(almacen: almacen, reloj: reloj);
    await restaurada.restaurar();
    expect(restaurada.autenticado, isTrue);

    final invalido = AlmacenTokensMemoria()..refresh = 'refresh-desconocido';
    final sinSesion = tec.crearSesion(almacen: invalido, reloj: reloj);
    await sinSesion.restaurar();
    expect(sinSesion.autenticado, isFalse);
    expect(invalido.refresh, isNull);
  });

  test('restaurar sin red conserva el refresh', () async {
    final almacen = AlmacenTokensMemoria()..refresh = 'refresh-x';
    tec.sinConexion = true;
    final sesion = tec.crearSesion(almacen: almacen, reloj: reloj);
    await sesion.restaurar();
    expect(sesion.autenticado, isFalse);
    expect(almacen.refresh, 'refresh-x');
  });

  test('cerrar revoca en TEC y borra lo local', () async {
    final almacen = AlmacenTokensMemoria();
    final sesion = tec.crearSesion(almacen: almacen, reloj: reloj);
    await sesion.iniciarSesion('presidente', 'Clave123');
    await sesion.cerrar();
    expect(sesion.autenticado, isFalse);
    expect(almacen.refresh, isNull);
    expect(tec.rutas.last, '/auth/logout');
  });
}

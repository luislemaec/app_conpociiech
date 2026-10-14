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
    AppConpociiech(
      entorno: Entorno.desdeUrl(Entorno.urlPorDefecto),
      sesion: sesion,
      cliente: tec.api,
    ),
  );
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
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();
  }
}

/// Desplaza la lista de miembros hasta el lápiz del miembro y lo toca.
Future<void> tocarLapiz(WidgetTester tester, String nombre) async {
  final lapiz = find.byTooltip('Editar datos de $nombre');
  await tester.scrollUntilVisible(
    lapiz,
    200,
    scrollable: find
        .descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
  await tester.tap(lapiz);
  await tester.pumpAndSettle();
  await esperar(tester);
}

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
      )
      ..usuarios['tribunal'] = UsuarioSimulado(
        clave: 'Clave123',
        roles: [RolTec.tribunal],
      )
      ..usuarios['varios'] = UsuarioSimulado(
        clave: 'Clave123',
        roles: [RolTec.iglesiaAdmin, RolTec.presidenteMesa],
      )
      ..usuarios['tecnico'] = UsuarioSimulado(
        clave: 'Clave123',
        roles: [RolTec.tecnico],
      );
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

    testWidgets('roles sin funciones en V1 no entran al módulo', (
      tester,
    ) async {
      await montar(tester, 'tecnico');
      await ir(tester, Rutas.tribunal);
      expect(find.text('Iniciar sesión'), findsNothing);
      expect(find.text('Mi mesa'), findsNothing);
      expect(find.text('Tribunal Electoral'), findsNothing);
    });
  });

  group('Presidente de mesa', () {
    testWidgets(
      'muestra la mesa, la junta y oculta resultados si no está cerrada',
      (tester) async {
        await montar(tester, 'presidente');
        await ir(tester, Rutas.miMesa);
        expect(find.text('MESA 7'), findsOneWidget);
        expect(find.text('Abierta'), findsOneWidget);
        expect(find.text('Pérez Ana'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Los resultados se muestran cuando la mesa está cerrada.'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(
          find.text('Los resultados se muestran cuando la mesa está cerrada.'),
          findsOneWidget,
        );
      },
    );

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
    Uri ultimaConsultaMiembros() =>
        tec.consultas.lastWhere((u) => u.path.endsWith('/miembros'));

    testWidgets('muestra la iglesia y su resumen', (tester) async {
      await montar(tester, 'iglesia');
      await ir(tester, Rutas.miIglesia);
      expect(find.text('Iglesia Central'), findsOneWidget);
      expect(find.text('Habilitados / Total'), findsOneWidget);
      expect(find.text('23 / 45'), findsOneWidget);
    });

    testWidgets('miembros por páginas y filtro de habilitación', (
      tester,
    ) async {
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

  group('Pendientes de revisión', () {
    Uri ultimaConsultaMiembros() =>
        tec.consultas.lastWhere((u) => u.path.endsWith('/miembros'));

    testWidgets('Mi iglesia ofrece ir a los pendientes con su cantidad', (
      tester,
    ) async {
      await montar(tester, 'iglesia');
      await ir(tester, Rutas.miIglesia);
      await tester.scrollUntilVisible(
        find.text('Ver pendientes de revisión (30)'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Ver pendientes de revisión (30)'));
      await esperar(tester);
      expect(ultimaConsultaMiembros().queryParameters['revisado'], 'false');
      expect(find.text('30 pendientes de revisión'), findsOneWidget);
      expect(find.textContaining('Pendiente de revisión'), findsWidgets);
    });

    testWidgets(
      'el filtro se combina con el de habilitación y se puede quitar',
      (tester) async {
        await montar(tester, 'iglesia');
        await ir(tester, '${Rutas.miembrosIglesia}?pendientes=1');
        await tester.tap(find.text('No habilitados'));
        await esperar(tester);
        expect(
          ultimaConsultaMiembros().queryParameters,
          containsPair('revisado', 'false'),
        );
        expect(
          ultimaConsultaMiembros().queryParameters,
          containsPair('habilitado', 'false'),
        );
        expect(find.text('15 pendientes de revisión'), findsOneWidget);

        await tester.tap(find.text('Pendientes de revisión'));
        await esperar(tester);
        expect(
          ultimaConsultaMiembros().queryParameters.containsKey('revisado'),
          isFalse,
        );
        expect(find.text('22 miembros'), findsOneWidget);
      },
    );

    testWidgets(
      'cambiar la habilitación de un pendiente lo marca como revisado',
      (tester) async {
        await montar(tester, 'iglesia');
        await ir(tester, '${Rutas.miembrosIglesia}?pendientes=1');
        await tocarLapiz(tester, 'Miembro 01');
        await tester.ensureVisible(
          find.widgetWithText(SwitchListTile, 'Habilitar para padrón'),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(SwitchListTile, 'Habilitar para padrón'),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.widgetWithText(FilledButton, 'Guardar cambios'),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Guardar cambios'));
        await esperar(tester);
        expect(tec.miembros[0]['revisado'], isTrue);
        expect(tec.miembros[0]['habilitado'], isFalse);
        // La fila se actualizó en su lugar: ya no está pendiente.
        expect(find.byTooltip('Editar datos de Miembro 01'), findsOneWidget);
        expect(
          find.descendant(
            of: find
                .ancestor(
                  of: find.text('Miembro 01'),
                  matching: find.byType(Row),
                )
                .first,
            matching: find.text('Pendiente de revisión'),
          ),
          findsNothing,
        );
      },
    );

    test('la App pide los pendientes con revisado=false', () async {
      final sesion = tec.crearSesion();
      await sesion.iniciarSesion('iglesia', 'Clave123');
      final pagina = await ApiTribunal(
        tec.api,
        sesion,
      ).miembros(revisado: false);
      expect(pagina.total, 30);
      expect(pagina.elementos.every((m) => !m.revisado), isTrue);
    });
  });

  group('Miembros: solo consulta', () {
    testWidgets('no tiene controles editables; el lápiz es la única acción', (
      tester,
    ) async {
      await montar(tester, 'iglesia');
      await ir(tester, Rutas.miembrosIglesia);
      expect(find.byType(Switch), findsNothing);
      expect(find.byType(SwitchListTile), findsNothing);
      expect(find.byType(Checkbox), findsNothing);
      expect(find.byTooltip('Editar datos de Miembro 01'), findsOneWidget);
      // Tocar la fila no abre ni cambia nada.
      await tester.tap(find.text('Miembro 01'));
      await esperar(tester);
      expect(find.text('Datos de la persona'), findsNothing);
      expect(tec.cuerpos, isEmpty);
    });

    testWidgets(
      'muestra sexo, estado del padrón y revisión pendiente con texto',
      (tester) async {
        await montar(tester, 'iglesia');
        await ir(tester, Rutas.miembrosIglesia);
        // Miembro 01: M, habilitado, pendiente. Miembro 02: F, no habilitado.
        // Miembro 05: sin dato de sexo.
        Finder enFila(String nombre, String texto) => find.descendant(
          of: find
              .ancestor(of: find.text(nombre), matching: find.byType(Row))
              .first,
          matching: find.text(texto),
        );
        expect(enFila('Miembro 01', 'Masculino'), findsOneWidget);
        expect(enFila('Miembro 01', 'Habilitado'), findsOneWidget);
        expect(enFila('Miembro 01', 'Pendiente de revisión'), findsOneWidget);
        expect(enFila('Miembro 02', 'Femenino'), findsOneWidget);
        expect(enFila('Miembro 02', 'No habilitado'), findsOneWidget);
        expect(
          enFila('Miembro 03', 'Pendiente de revisión'),
          findsNothing,
          reason: 'revisado',
        );
        await tester.scrollUntilVisible(
          find.text('Miembro 05'),
          200,
          scrollable: find.byType(Scrollable).last,
        );
        expect(enFila('Miembro 05', 'Sin dato'), findsOneWidget);
      },
    );

    test('solo el IglesiaAdmin puede cambiar la habilitación', () async {
      final sesion = tec.crearSesion();
      await sesion.iniciarSesion('tribunal', 'Clave123');
      await expectLater(
        ApiTribunal(tec.api, sesion).cambiarHabilitacion(2, true),
        throwsA(errorApi('SIN_PERMISO')),
      );
    });
  });

  group('Editar datos de la persona', () {
    Future<void> abrirEdicion(WidgetTester tester, String nombre) async {
      // Pantalla alta: el formulario completo (hasta «Guardar») queda construido.
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await montar(tester, 'iglesia');
      await ir(tester, Rutas.miembrosIglesia);
      await tocarLapiz(tester, nombre);
    }

    Finder habilitar() =>
        find.widgetWithText(SwitchListTile, 'Habilitar para padrón');

    Finder campo(String etiqueta) =>
        find.widgetWithText(TextFormField, etiqueta);
    Finder guardar() => find.widgetWithText(FilledButton, 'Guardar cambios');

    /// Lleva el botón a la vista, redibuja y toca (el toque se calcula sobre la vista final).
    Future<void> tocarGuardar(WidgetTester tester) async {
      await tester.ensureVisible(guardar());
      await tester.pumpAndSettle();
      await tester.tap(guardar());
      await esperar(tester);
    }

    testWidgets('consulta el detalle actualizado a TEC', (tester) async {
      await abrirEdicion(tester, 'Miembro 04');
      expect(
        tec.consultas.any(
          (u) => u.path.endsWith('/tribunal/iglesia/miembros/4'),
        ),
        isTrue,
      );
      expect(find.text('Miembro 04'), findsWidgets);
      expect(find.text('1710034065'), findsOneWidget);
      // Sin cambios no se puede guardar ni se envía nada.
      expect(tester.widget<FilledButton>(guardar()).onPressed, isNull);
      expect(tec.actualizacionesPersona, 0);
    });

    testWidgets('guarda solo los campos permitidos y actualiza la fila', (
      tester,
    ) async {
      await abrirEdicion(tester, 'Miembro 04'); // F, no habilitado
      final consultasLista = tec.consultas
          .where((u) => u.path.endsWith('/miembros'))
          .length;
      await tester.enterText(campo('Apellidos y nombres'), 'PEREZ LOPEZ JUAN');
      await tester.tap(find.text('Masculino'));
      await tester.pumpAndSettle();
      await tocarGuardar(tester);

      expect(tec.actualizacionesPersona, 1);
      final cuerpo = tec.cuerpos.last;
      // Sin cambio de habilitación no se envía «habilitado».
      expect(cuerpo.keys.toSet(), {'nombres', 'documento', 'sexo'});
      expect(cuerpo['nombres'], 'PEREZ LOPEZ JUAN');
      expect(cuerpo['sexo'], 'M');
      // Volvió a la lista con solo esa fila actualizada (sin volver a consultar la lista).
      expect(
        find.byTooltip('Editar datos de PEREZ LOPEZ JUAN'),
        findsOneWidget,
      );
      expect(
        tec.consultas.where((u) => u.path.endsWith('/miembros')).length,
        consultasLista,
      );
      expect(find.text('Datos de la persona actualizados.'), findsOneWidget);
    });

    testWidgets('solo la habilitación: TEC no toca los datos de la persona', (
      tester,
    ) async {
      await abrirEdicion(tester, 'Miembro 04'); // no habilitado
      expect(tester.widget<SwitchListTile>(habilitar()).value, isFalse);
      await tester.tap(habilitar());
      await tester.pumpAndSettle();
      await tocarGuardar(tester);
      expect(tec.cuerpos.last['habilitado'], isTrue);
      expect(tec.soloHabilitaciones, 1);
      expect(
        tec.actualizacionesPersona,
        0,
        reason: 'Persona no se actualiza artificialmente',
      );
      expect(tec.miembros[3]['habilitado'], isTrue);
      final fila = find
          .ancestor(of: find.text('Miembro 04'), matching: find.byType(Row))
          .first;
      expect(
        find.descendant(of: fila, matching: find.text('Habilitado')),
        findsOneWidget,
      );
    });

    testWidgets('datos y habilitación se guardan en una sola acción', (
      tester,
    ) async {
      await abrirEdicion(tester, 'Miembro 04');
      await tester.enterText(campo('Apellidos y nombres'), 'PEREZ LOPEZ JUAN');
      await tester.ensureVisible(habilitar());
      await tester.pumpAndSettle();
      await tester.tap(habilitar());
      await tester.pumpAndSettle();
      await tocarGuardar(tester);
      expect(
        tec.cuerpos.where((c) => c.containsKey('nombres')),
        hasLength(1),
        reason: 'una sola petición',
      );
      expect(tec.actualizacionesPersona, 1);
      expect(tec.miembros[3]['habilitado'], isTrue);
    });

    testWidgets('muestra el sexo con ícono y texto', (tester) async {
      await abrirEdicion(tester, 'Miembro 04');
      for (final (texto, icono) in const [
        ('Masculino', Icons.male),
        ('Femenino', Icons.female),
        ('Sin dato', Icons.person_outline),
      ]) {
        final segmento = find
            .ancestor(of: find.text(texto), matching: find.byType(InkWell))
            .first;
        expect(
          find.descendant(of: segmento, matching: find.byIcon(icono)),
          findsOneWidget,
        );
      }
    });

    testWidgets('valida los campos antes de enviar', (tester) async {
      await abrirEdicion(tester, 'Miembro 04');
      await tester.enterText(campo('Apellidos y nombres'), '   ');
      await tester.enterText(campo('Cédula'), '12345');
      await tocarGuardar(tester);
      expect(find.text('Ingrese los apellidos y nombres.'), findsOneWidget);
      expect(find.text('La cédula debe tener 10 dígitos.'), findsOneWidget);
      expect(tec.actualizacionesPersona, 0);
    });

    testWidgets(
      'muestra las reglas de TEC: dígito verificador y cédula duplicada',
      (tester) async {
        await abrirEdicion(tester, 'Miembro 04');
        await tester.enterText(campo('Cédula'), TecSimulado.cedulaInvalida);
        await tocarGuardar(tester);
        expect(find.text('La cédula ingresada no es válida.'), findsOneWidget);

        await tester.enterText(
          campo('Cédula'),
          TecSimulado.cedulaDeOtraPersona,
        );
        await tocarGuardar(tester);
        expect(
          find.text('La cédula ingresada ya pertenece a otra persona.'),
          findsOneWidget,
        );
        expect(tec.actualizacionesPersona, 0);
      },
    );

    testWidgets('sin conexión al guardar informa y conserva lo escrito', (
      tester,
    ) async {
      await abrirEdicion(tester, 'Miembro 04');
      await tester.enterText(campo('Apellidos y nombres'), 'PEREZ LOPEZ JUAN');
      tec.sinConexion = true;
      await tocarGuardar(tester);
      expect(find.textContaining('No se pudo conectar'), findsOneWidget);
      expect(find.text('PEREZ LOPEZ JUAN'), findsOneWidget);
      expect(tec.actualizacionesPersona, 0);
    });

    testWidgets('con el cronograma cerrado se consulta pero no se edita', (
      tester,
    ) async {
      tec.edicionAbierta = false;
      await abrirEdicion(tester, 'Miembro 04');
      expect(
        find.textContaining('fase del cronograma que permite editar'),
        findsOneWidget,
      );
      expect(
        tester.widget<TextFormField>(campo('Apellidos y nombres')).enabled,
        isFalse,
      );
      expect(tester.widget<SwitchListTile>(habilitar()).onChanged, isNull);
      expect(tester.widget<FilledButton>(guardar()).onPressed, isNull);
    });

    testWidgets(
      'si el cronograma se cierra antes de guardar, informa el mensaje de TEC',
      (tester) async {
        await abrirEdicion(tester, 'Miembro 04');
        tec.edicionAbierta = false;
        await tester.tap(habilitar());
        await tester.pumpAndSettle();
        await tocarGuardar(tester);
        expect(
          find.textContaining('cerrada por el cronograma'),
          findsOneWidget,
        );
        expect(tec.miembros[3]['habilitado'], isFalse);
      },
    );

    test(
      'un miembro de otra iglesia se rechaza aunque se conozca su id',
      () async {
        final sesion = tec.crearSesion();
        await sesion.iniciarSesion('iglesia', 'Clave123');
        final api = ApiTribunal(tec.api, sesion);
        await expectLater(
          api.detalleMiembro(TecSimulado.miembroDeOtraIglesia),
          throwsA(errorApi('SIN_PERMISO')),
        );
        await expectLater(
          api.actualizarPersona(
            TecSimulado.miembroDeOtraIglesia,
            nombres: 'X',
            documento: '1710034065',
          ),
          throwsA(errorApi('SIN_PERMISO')),
        );
      },
    );

    test('un usuario sin rol IglesiaAdmin no puede editar', () async {
      final sesion = tec.crearSesion();
      await sesion.iniciarSesion('tribunal', 'Clave123');
      await expectLater(
        ApiTribunal(
          tec.api,
          sesion,
        ).actualizarPersona(4, nombres: 'X', documento: '1710034065'),
        throwsA(errorApi('SIN_PERMISO')),
      );
    });
  });

  group('Tribunal / Administrador', () {
    testWidgets('resumen del proceso', (tester) async {
      await montar(tester, 'tribunal');
      await ir(tester, Rutas.proceso);
      expect(find.text('Elecciones 2026'), findsOneWidget);
      expect(find.text('1 (50 %)'), findsOneWidget);
    });

    testWidgets('avance de mesas: fase de TEC y filtro por fase con contadores', (
      tester,
    ) async {
      await montar(tester, 'tribunal');
      await ir(tester, Rutas.avanceMesas);
      expect(find.text('2 de 2 mesas'), findsOneWidget);
      // Cada mesa muestra la fase que calcula TEC (misma que la columna Situación de actaE).
      expect(find.text('2. Conteo'), findsOneWidget);
      expect(find.text('5. Validación'), findsOneWidget);
      // Ya no se muestra ni filtra el estado crudo de la base.
      expect(find.text('Abierta'), findsNothing);
      expect(find.text('Cerrada'), findsNothing);
      // Las cinco fases en orden oficial, también las que no tienen mesas.
      for (final opcion in [
        'Todas (2)',
        'Apertura (0)',
        'Conteo (1)',
        'Acta física (0)',
        'Cierre (0)',
        'Validación (1)',
      ]) {
        expect(find.text(opcion), findsOneWidget, reason: opcion);
      }

      await tester.tap(find.text('Validación (1)'));
      await tester.pumpAndSettle();
      expect(find.text('1 de 2 mesas'), findsOneWidget);
      expect(find.text('MESA 8'), findsOneWidget);
      expect(find.text('MESA 7'), findsNothing);

      await tester.tap(find.text('Cierre (0)'));
      await tester.pumpAndSettle();
      expect(
        find.text('No hay resultados para los filtros seleccionados.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Todas (2)'));
      await tester.pumpAndSettle();
      expect(find.text('2 de 2 mesas'), findsOneWidget);
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
      await expectLater(
        ApiTribunal(tec.api, sesion).iglesia(),
        throwsA(errorApi('SIN_PERMISO')),
      );
    });

    test('la URL lleva los parámetros de consulta', () async {
      final sesion = tec.crearSesion();
      await sesion.iniciarSesion('iglesia', 'Clave123');
      await ApiTribunal(
        tec.api,
        sesion,
      ).miembros(busqueda: ' ana ', habilitado: true, pagina: 2);
      final url = tec.consultas.last;
      expect(url.path, '/api/v1/tribunal/iglesia/miembros');
      expect(url.queryParameters, {
        'busqueda': 'ana',
        'habilitado': 'true',
        'pagina': '2',
        'tamano': '30',
      });
    });
  });
}

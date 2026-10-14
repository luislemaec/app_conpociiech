import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_router.dart';
import '../../core/sesion/roles.dart';
import '../../core/sesion/sesion_controller.dart';
import '../../shared/tema/diseno_app.dart';
import '../../shared/widgets/componentes_institucionales.dart';
import '../../shared/widgets/entrada_animada.dart';
import '../organizacion/contenido_institucional.dart';

/// Servicios: acceso al sistema TEC (Tribunal Electoral) y a la cuenta del usuario.
/// Solo decide qué se muestra; las guardas de rutas y TEC siguen autorizando cada
/// acceso y cada consulta.
class PantallaServicios extends StatelessWidget {
  const PantallaServicios({super.key});

  @override
  Widget build(BuildContext context) {
    final sesion = context.watch<SesionController>();
    var orden = 0;
    Widget bloque(Widget hijo) => EntradaAnimada(
      retardo: Duration(milliseconds: 70 * orden++),
      child: hijo,
    );

    return ContenidoLimitado(
      child: ListView(
        padding: DisenoApp.margen(MediaQuery.sizeOf(context).width),
        children: [
          bloque(
            const EncabezadoInstitucional(
              icono: Icons.apps_outlined,
              titulo: 'Servicios',
              descripcion:
                  'Servicios digitales de CONPOCIIECH disponibles en la aplicación.',
            ),
          ),
          separacionBloque,
          bloque(
            SeccionCard(
              icono: Icons.how_to_vote_outlined,
              titulo: 'Servicios electorales',
              children: [
                const Text(ContenidoInstitucional.procesoElectoral),
                const SizedBox(height: DisenoApp.md),
                _AccesoTribunal(sesion: sesion),
                if (sesion.puedeAccederTribunal) ...[
                  if (sesion.tieneAlgunRol(RolTec.seccionMesa))
                    const _AccesoSeccion(
                      icono: Icons.table_restaurant_outlined,
                      titulo: 'Mi mesa',
                      descripcion:
                          'Estado, junta, padrón y resultados de su mesa.',
                      ruta: Rutas.miMesa,
                    ),
                  if (sesion.tieneAlgunRol(RolTec.seccionIglesia))
                    const _AccesoSeccion(
                      icono: Icons.church_outlined,
                      titulo: 'Mi iglesia',
                      descripcion:
                          'Datos de la iglesia y habilitación de sus miembros.',
                      ruta: Rutas.miIglesia,
                    ),
                  if (sesion.tieneAlgunRol(RolTec.seccionProceso))
                    const _AccesoSeccion(
                      icono: Icons.insights_outlined,
                      titulo: 'Proceso electoral',
                      descripcion:
                          'Resumen, avance de mesas y resultados consolidados.',
                      ruta: Rutas.proceso,
                    ),
                ],
              ],
            ),
          ),
          separacionBloque,
          bloque(
            SeccionCard(
              icono: Icons.manage_accounts_outlined,
              titulo: 'Mi cuenta',
              children: [
                if (!sesion.autenticado)
                  TarjetaServicio(
                    icono: Icons.login,
                    titulo: 'Ingresar con su usuario TEC',
                    descripcion:
                        'Use el usuario y la contraseña asignados en el sistema del Tribunal Electoral.',
                    alTocar: () => context.go(Rutas.iniciarSesion),
                  )
                else ...[
                  if (sesion.nombreUsuario != null) ...[
                    Text(
                      sesion.nombreUsuario!,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: DisenoApp.sm),
                  ],
                  TarjetaServicio(
                    icono: Icons.password,
                    titulo: 'Cambiar contraseña',
                    descripcion: 'Actualice la contraseña de su usuario TEC.',
                    alTocar: () => context.go(Rutas.cambiarClave),
                  ),
                  const SizedBox(height: DisenoApp.sm),
                  OutlinedButton.icon(
                    onPressed: sesion.cerrar,
                    icon: const Icon(Icons.logout),
                    label: const Text('Cerrar sesión'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: DisenoApp.lg),
        ],
      ),
    );
  }
}

/// Entrada al módulo Tribunal según el estado de la sesión.
class _AccesoTribunal extends StatelessWidget {
  const _AccesoTribunal({required this.sesion});

  final SesionController sesion;

  @override
  Widget build(BuildContext context) {
    if (!sesion.autenticado) {
      return TarjetaServicio(
        icono: Icons.how_to_vote_outlined,
        titulo: 'Sistema del Tribunal Electoral (TEC)',
        descripcion:
            'Presidentes de mesa, administradores de iglesia y Tribunal.',
        etiqueta: 'Requiere iniciar sesión',
        destacada: true,
        // Tras autenticarse vuelve al módulo (destino validado por destinoSeguro).
        alTocar: () => context.go(
          Uri(
            path: Rutas.iniciarSesion,
            queryParameters: {Rutas.destino: Rutas.tribunal},
          ).toString(),
        ),
      );
    }
    if (!sesion.puedeAccederTribunal) {
      return const TarjetaServicio(
        icono: Icons.how_to_vote_outlined,
        titulo: 'Sistema del Tribunal Electoral (TEC)',
        descripcion:
            'Su usuario no tiene funciones del Tribunal Electoral asignadas en la aplicación.',
      );
    }
    return TarjetaServicio(
      icono: Icons.how_to_vote_outlined,
      titulo: 'Sistema del Tribunal Electoral (TEC)',
      descripcion: 'Acceda a las funciones disponibles para sus roles en TEC.',
      destacada: true,
      alTocar: () => context.go(Rutas.tribunal),
    );
  }
}

class _AccesoSeccion extends StatelessWidget {
  const _AccesoSeccion({
    required this.icono,
    required this.titulo,
    required this.descripcion,
    required this.ruta,
  });

  final IconData icono;
  final String titulo;
  final String descripcion;
  final String ruta;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: DisenoApp.sm),
      child: TarjetaServicio(
        icono: icono,
        titulo: titulo,
        descripcion: descripcion,
        alTocar: () => context.go(ruta),
      ),
    );
  }
}

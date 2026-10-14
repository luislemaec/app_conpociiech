import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_router.dart';
import '../../core/sesion/sesion_controller.dart';
import '../../shared/tema/colores_tribunal.dart';
import '../../shared/tema/diseno_app.dart';
import '../../shared/widgets/componentes_institucionales.dart';
import '../../shared/widgets/entrada_animada.dart';
import '../../shared/widgets/logo_institucional.dart';
import '../organizacion/contenido_institucional.dart';

/// Inicio público: identidad oficial, acceso a la cuenta y accesos a Organización y
/// Servicios. Solo contenido publicado por la organización (ver [ContenidoInstitucional]).
class PantallaInicio extends StatelessWidget {
  const PantallaInicio({super.key});

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
          bloque(const _Identidad()),
          separacionBloque,
          bloque(_Cuenta(sesion: sesion)),
          separacionBloque,
          bloque(
            SeccionCard(
              icono: Icons.how_to_vote_outlined,
              titulo: 'Proceso electoral 2026',
              children: [
                const Text(ContenidoInstitucional.procesoElectoral),
                const SizedBox(height: DisenoApp.md),
                OutlinedButton.icon(
                  onPressed: () => context.go(Rutas.servicios),
                  icon: const Icon(Icons.apps_outlined),
                  label: const Text('Ver servicios electorales'),
                ),
              ],
            ),
          ),
          separacionBloque,
          bloque(
            TarjetaServicio(
              icono: Icons.account_balance_outlined,
              titulo: 'Organización',
              descripcion:
                  'Quiénes somos, nuestras instituciones y departamentos.',
              alTocar: () => context.go(Rutas.organizacion),
            ),
          ),
          const SizedBox(height: DisenoApp.sm),
          bloque(
            TarjetaServicio(
              icono: Icons.apps_outlined,
              titulo: 'Servicios',
              descripcion: 'Servicios electorales y gestión de su cuenta.',
              alTocar: () => context.go(Rutas.servicios),
            ),
          ),
          const SizedBox(height: DisenoApp.lg),
        ],
      ),
    );
  }
}

/// Logo oficial sobre fondo claro (sus letras son azul oscuro) y franja con el lema.
class _Identidad extends StatelessWidget {
  const _Identidad();

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    // Identidad plana: logo, nombre, subtítulo y lema, sin degradados ni sombras.
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(DisenoApp.lg),
        child: Column(
          children: [
            const LogoInstitucional(ancho: 150),
            const SizedBox(height: DisenoApp.md),
            Text(
              ContenidoInstitucional.sigla,
              textAlign: TextAlign.center,
              style: texto.headlineSmall,
            ),
            const SizedBox(height: DisenoApp.xs),
            Text(
              ContenidoInstitucional.subtitulo,
              textAlign: TextAlign.center,
              style: texto.titleMedium,
            ),
            const SizedBox(height: DisenoApp.sm),
            Text(
              ContenidoInstitucional.lema,
              textAlign: TextAlign.center,
              style: texto.bodyMedium?.copyWith(
                color: ColoresTribunal.primario,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Estado de la cuenta: iniciar sesión, entrar al Tribunal o cerrar sesión.
class _Cuenta extends StatelessWidget {
  const _Cuenta({required this.sesion});

  final SesionController sesion;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return SeccionCard(
      icono: Icons.person_outline,
      titulo: 'Mi cuenta',
      children: [
        if (!sesion.autenticado) ...[
          Text(
            'Presidentes de mesa, administradores de iglesia y Tribunal pueden ingresar con su usuario TEC.',
            style: texto.bodyMedium,
          ),
          const SizedBox(height: DisenoApp.md),
          FilledButton.icon(
            onPressed: () => context.go(Rutas.iniciarSesion),
            icon: const Icon(Icons.login),
            label: const Text('Iniciar sesión'),
          ),
        ] else ...[
          if (sesion.nombreUsuario != null) ...[
            Text(sesion.nombreUsuario!, style: texto.titleMedium),
            const SizedBox(height: DisenoApp.md),
          ],
          if (sesion.puedeAccederTribunal) ...[
            FilledButton.icon(
              onPressed: () => context.go(Rutas.tribunal),
              icon: const Icon(Icons.how_to_vote_outlined),
              label: const Text('Tribunal Electoral'),
            ),
            const SizedBox(height: DisenoApp.sm),
          ],
          OutlinedButton.icon(
            onPressed: sesion.cerrar,
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar sesión'),
          ),
        ],
      ],
    );
  }
}

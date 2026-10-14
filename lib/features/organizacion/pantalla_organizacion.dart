import 'package:flutter/material.dart';

import '../../shared/tema/colores_tribunal.dart';
import '../../shared/tema/diseno_app.dart';
import '../../shared/widgets/componentes_institucionales.dart';
import '../../shared/widgets/entrada_animada.dart';
import '../../shared/widgets/logo_institucional.dart';
import 'contenido_institucional.dart';

/// Organización: identidad, quiénes somos, instituciones y departamentos publicados.
/// Pública; solo muestra contenido de [ContenidoInstitucional].
class PantallaOrganizacion extends StatelessWidget {
  const PantallaOrganizacion({super.key});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
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
              icono: Icons.account_balance_outlined,
              titulo: ContenidoInstitucional.subtitulo,
              descripcion: ContenidoInstitucional.lema,
            ),
          ),
          separacionBloque,
          bloque(
            SeccionCard(
              icono: Icons.info_outline,
              titulo: 'Quiénes somos',
              children: [
                const Center(child: LogoInstitucional(ancho: 140)),
                const SizedBox(height: DisenoApp.md),
                Text(
                  ContenidoInstitucional.nombreCompleto,
                  textAlign: TextAlign.center,
                  style: tema.textTheme.titleSmall?.copyWith(
                    color: ColoresTribunal.azulInstitucional,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: DisenoApp.md),
                const Text(ContenidoInstitucional.quienesSomos),
              ],
            ),
          ),
          separacionBloque,
          bloque(
            SeccionCard(
              icono: Icons.diversity_3_outlined,
              titulo: 'Nuestras instituciones',
              children: [
                const Text(ContenidoInstitucional.introInstituciones),
                for (final area in ContenidoInstitucional.areas) ...[
                  const SizedBox(height: DisenoApp.md),
                  Text(
                    area.nombre,
                    style: tema.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: DisenoApp.sm),
                  for (final institucion in area.instituciones) ...[
                    TarjetaServicio(
                      icono: area.nombre == 'Educación'
                          ? Icons.school_outlined
                          : Icons.volunteer_activism_outlined,
                      titulo: institucion.nombre,
                      descripcion: institucion.descripcion,
                    ),
                    const SizedBox(height: DisenoApp.sm),
                  ],
                ],
              ],
            ),
          ),
          separacionBloque,
          bloque(
            const SeccionCard(
              icono: Icons.apartment_outlined,
              titulo: 'Departamentos',
              children: [
                TarjetaServicio(
                  icono: Icons.how_to_vote_outlined,
                  titulo: 'Tribunal Electoral',
                  descripcion: ContenidoInstitucional.tribunalElectoral,
                ),
              ],
            ),
          ),
          const SizedBox(height: DisenoApp.lg),
          Text(
            'Fuente: ${ContenidoInstitucional.sitioWeb}',
            textAlign: TextAlign.center,
            style: tema.textTheme.bodySmall,
          ),
          const SizedBox(height: DisenoApp.lg),
        ],
      ),
    );
  }
}

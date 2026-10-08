import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_router.dart';
import '../../core/sesion/roles.dart';
import '../../core/sesion/sesion_controller.dart';

/// Módulo Tribunal Electoral (área autenticada, solo lectura). Muestra la unión de las
/// secciones de los roles del usuario; TEC vuelve a autorizar cada consulta.
class PantallaTribunal extends StatelessWidget {
  const PantallaTribunal({super.key});

  @override
  Widget build(BuildContext context) {
    final sesion = context.watch<SesionController>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tribunal Electoral'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Inicio',
          onPressed: () => context.go(Rutas.inicio),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.password),
            tooltip: 'Cambiar contraseña',
            onPressed: () => context.go(Rutas.cambiarClave),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: sesion.cerrar,
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (sesion.nombreUsuario != null) ...[
                Text(sesion.nombreUsuario!, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 16),
              ],
              if (sesion.tieneAlgunRol(RolTec.seccionMesa))
                const _Opcion(
                  icono: Icons.how_to_vote_outlined,
                  titulo: 'Mi mesa',
                  descripcion: 'Estado, junta, padrón y resultados de su mesa.',
                  ruta: Rutas.miMesa,
                ),
              if (sesion.tieneAlgunRol(RolTec.seccionIglesia))
                const _Opcion(
                  icono: Icons.church_outlined,
                  titulo: 'Mi iglesia',
                  descripcion: 'Datos de la iglesia y habilitación de sus miembros.',
                  ruta: Rutas.miIglesia,
                ),
              if (sesion.tieneAlgunRol(RolTec.seccionProceso))
                const _Opcion(
                  icono: Icons.insights_outlined,
                  titulo: 'Proceso electoral',
                  descripcion: 'Resumen, avance de mesas y resultados consolidados.',
                  ruta: Rutas.proceso,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Opcion extends StatelessWidget {
  const _Opcion({required this.icono, required this.titulo, required this.descripcion, required this.ruta});

  final IconData icono;
  final String titulo;
  final String descripcion;
  final String ruta;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icono),
        title: Text(titulo),
        subtitle: Text(descripcion),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.go(ruta),
      ),
    );
  }
}

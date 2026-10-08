import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_router.dart';
import '../../core/sesion/sesion_controller.dart';
import '../../shared/widgets/logo_institucional.dart';

/// Inicio público. Por ahora solo identidad e «Iniciar sesión»: no se agregan módulos
/// públicos que no hayan sido definidos.
class PantallaInicio extends StatelessWidget {
  const PantallaInicio({super.key});

  @override
  Widget build(BuildContext context) {
    final sesion = context.watch<SesionController>();
    final tema = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: LogoInstitucional(ancho: 240)),
                  const SizedBox(height: 24),
                  Text('CONPOCIIECH', textAlign: TextAlign.center, style: tema.textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(
                    'Aplicación institucional',
                    textAlign: TextAlign.center,
                    style: tema.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 40),
                  if (sesion.puedeAccederTribunal)
                    FilledButton.icon(
                      onPressed: () => context.go(Rutas.tribunal),
                      icon: const Icon(Icons.how_to_vote_outlined),
                      label: const Text('Tribunal Electoral'),
                    )
                  else if (!sesion.autenticado)
                    FilledButton.icon(
                      onPressed: () => context.go(Rutas.iniciarSesion),
                      icon: const Icon(Icons.login),
                      label: const Text('Iniciar sesión'),
                    ),
                  if (sesion.autenticado) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: sesion.cerrar,
                      icon: const Icon(Icons.logout),
                      label: const Text('Cerrar sesión'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

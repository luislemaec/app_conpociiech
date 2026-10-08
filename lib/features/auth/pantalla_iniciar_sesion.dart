import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api/cliente_api.dart';
import '../../core/router/app_router.dart';
import '../../core/sesion/sesion_controller.dart';
import '../../shared/widgets/logo_institucional.dart';

/// Formulario de inicio de sesión con las credenciales de TEC. Al autenticarse, la guarda
/// de rutas lleva al destino (o al cambio de clave obligatorio). La contraseña se descarta
/// del campo tras cada intento y nunca se guarda.
class PantallaIniciarSesion extends StatefulWidget {
  const PantallaIniciarSesion({super.key, this.destino});

  /// Ruta a la que se vuelve tras autenticarse (p. ej. el módulo Tribunal).
  final String? destino;

  @override
  State<PantallaIniciarSesion> createState() => _PantallaIniciarSesionState();
}

class _PantallaIniciarSesionState extends State<PantallaIniciarSesion> {
  final _formulario = GlobalKey<FormState>();
  final _usuario = TextEditingController();
  final _clave = TextEditingController();
  bool _claveVisible = false;
  bool _enviando = false;
  String? _aviso;

  @override
  void initState() {
    super.initState();
    // Motivo de un cierre automático (inactividad o sesión expirada).
    _aviso = context.read<SesionController>().consumirAviso();
  }

  @override
  void dispose() {
    _usuario.dispose();
    _clave.dispose();
    super.dispose();
  }

  Future<void> _ingresar() async {
    if (_enviando || !(_formulario.currentState?.validate() ?? false)) return;
    final clave = _clave.text;
    _clave.clear();
    setState(() {
      _enviando = true;
      _aviso = null;
    });
    String? error;
    try {
      await context.read<SesionController>().iniciarSesion(_usuario.text, clave);
    } on ErrorApi catch (e) {
      error = e.mensaje;
    } on SinConexion {
      error = SinConexion.mensaje;
    }
    if (!mounted) return;
    setState(() => _enviando = false);
    if (error != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Iniciar sesión'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Volver',
          onPressed: () => context.go(Rutas.inicio),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formulario,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: LogoInstitucional(ancho: 160)),
                      const SizedBox(height: 16),
                      if (_aviso != null) ...[
                        Card(
                          color: tema.colorScheme.secondaryContainer,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, color: tema.colorScheme.onSecondaryContainer),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _aviso!,
                                    style: tema.textTheme.bodyMedium
                                        ?.copyWith(color: tema.colorScheme.onSecondaryContainer),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Text(
                        'Ingrese con su usuario y contraseña del sistema TEC.',
                        textAlign: TextAlign.center,
                        style: tema.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _usuario,
                        enabled: !_enviando,
                        decoration: const InputDecoration(
                          labelText: 'Usuario',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.username],
                        autocorrect: false,
                        enableSuggestions: false,
                        validator: (valor) =>
                            (valor == null || valor.trim().isEmpty) ? 'Ingrese su usuario.' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _clave,
                        enabled: !_enviando,
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_claveVisible ? Icons.visibility_off : Icons.visibility),
                            tooltip: _claveVisible ? 'Ocultar contraseña' : 'Mostrar contraseña',
                            onPressed: () => setState(() => _claveVisible = !_claveVisible),
                          ),
                        ),
                        obscureText: !_claveVisible,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        autocorrect: false,
                        enableSuggestions: false,
                        onFieldSubmitted: (_) => _ingresar(),
                        validator: (valor) =>
                            (valor == null || valor.isEmpty) ? 'Ingrese su contraseña.' : null,
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _enviando ? null : _ingresar,
                        child: _enviando
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Ingresar'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

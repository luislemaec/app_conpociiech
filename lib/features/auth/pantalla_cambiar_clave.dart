import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api/cliente_api.dart';
import '../../core/router/app_router.dart';
import '../../core/sesion/sesion_controller.dart';

/// Requisitos de la clave: los mismos que valida TEC (JsfUtil.cumplePoliticaContrasenia).
/// La marca en pantalla es solo una ayuda; la validación definitiva es la del servidor.
abstract final class PoliticaClave {
  static final Map<String, bool Function(String)> requisitos = {
    'Entre 8 y 16 caracteres': (v) => v.length >= 8 && v.length <= 16,
    'Al menos una letra mayúscula': (v) => RegExp('[A-Z]').hasMatch(v),
    'Al menos una letra minúscula': (v) => RegExp('[a-z]').hasMatch(v),
    'Al menos un número': (v) => RegExp(r'\d').hasMatch(v),
    'Sin espacios': (v) => v.isNotEmpty && !RegExp(r'\s').hasMatch(v),
  };

  static bool cumple(String clave) => requisitos.values.every((regla) => regla(clave));
}

/// Cambio de clave. Es obligatorio para un usuario no permanente (no puede usar otra
/// pantalla hasta hacerlo, igual que en la web) y voluntario para el resto.
class PantallaCambiarClave extends StatefulWidget {
  const PantallaCambiarClave({super.key});

  @override
  State<PantallaCambiarClave> createState() => _PantallaCambiarClaveState();
}

class _PantallaCambiarClaveState extends State<PantallaCambiarClave> {
  final _formulario = GlobalKey<FormState>();
  final _actual = TextEditingController();
  final _nueva = TextEditingController();
  final _confirmacion = TextEditingController();
  bool _visibles = false;
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _nueva.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _actual.dispose();
    _nueva.dispose();
    _confirmacion.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_enviando || !(_formulario.currentState?.validate() ?? false)) return;
    final sesion = context.read<SesionController>();
    final mensajes = ScaffoldMessenger.of(context);
    final actual = _actual.text;
    final nueva = _nueva.text;
    setState(() => _enviando = true);
    String? error;
    try {
      await sesion.cambiarClave(actual, nueva);
    } on ErrorApi catch (e) {
      error = e.mensaje;
    } on SinConexion {
      error = SinConexion.mensaje;
    }
    _actual.clear();
    _nueva.clear();
    _confirmacion.clear();
    if (!mounted) return;
    setState(() => _enviando = false);
    mensajes
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(error ?? 'Su contraseña se actualizó correctamente.')));
    if (error == null) context.go(destinoSeguro(null, sesion));
  }

  /// En el cambio obligatorio, «Cancelar» cierra la sesión (como en la web).
  Future<void> _cancelar(bool obligatorio) async {
    if (obligatorio) {
      await context.read<SesionController>().cerrar();
    } else if (mounted) {
      context.go(Rutas.inicio);
    }
  }

  InputDecoration _decoracion(String etiqueta) => InputDecoration(
        labelText: etiqueta,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(_visibles ? Icons.visibility_off : Icons.visibility),
          tooltip: _visibles ? 'Ocultar contraseñas' : 'Mostrar contraseñas',
          onPressed: () => setState(() => _visibles = !_visibles),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final obligatorio = context.select<SesionController, bool>((s) => s.cambioClaveObligatorio);
    final nueva = _nueva.text;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cambiar contraseña'),
        automaticallyImplyLeading: false,
        leading: obligatorio
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Volver',
                onPressed: () => _cancelar(false),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (obligatorio) ...[
                      Text(
                        'Por seguridad, debe cambiar la contraseña temporal antes de continuar.',
                        style: tema.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                    ],
                    TextFormField(
                      controller: _actual,
                      enabled: !_enviando,
                      obscureText: !_visibles,
                      autocorrect: false,
                      enableSuggestions: false,
                      autofillHints: const [AutofillHints.password],
                      textInputAction: TextInputAction.next,
                      decoration: _decoracion('Contraseña actual'),
                      validator: (v) => (v == null || v.isEmpty) ? 'Ingrese su contraseña actual.' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nueva,
                      enabled: !_enviando,
                      obscureText: !_visibles,
                      autocorrect: false,
                      enableSuggestions: false,
                      autofillHints: const [AutofillHints.newPassword],
                      textInputAction: TextInputAction.next,
                      decoration: _decoracion('Nueva contraseña'),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Ingrese la nueva contraseña.';
                        if (!PoliticaClave.cumple(v)) return 'La contraseña no cumple los requisitos.';
                        if (v == _actual.text) return 'La nueva contraseña debe ser distinta de la actual.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmacion,
                      enabled: !_enviando,
                      obscureText: !_visibles,
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: TextInputAction.done,
                      decoration: _decoracion('Confirmar nueva contraseña'),
                      onFieldSubmitted: (_) => _guardar(),
                      validator: (v) => v != _nueva.text ? 'Las contraseñas no coinciden.' : null,
                    ),
                    const SizedBox(height: 16),
                    Text('La contraseña debe tener:', style: tema.textTheme.labelLarge),
                    const SizedBox(height: 8),
                    for (final requisito in PoliticaClave.requisitos.entries)
                      _Requisito(texto: requisito.key, cumplido: requisito.value(nueva)),
                    const SizedBox(height: 4),
                    Text('Los símbolos son opcionales.', style: tema.textTheme.bodySmall),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _enviando ? null : _guardar,
                      child: _enviando
                          ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Guardar contraseña'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _enviando ? null : () => _cancelar(obligatorio),
                      child: Text(obligatorio ? 'Cancelar y cerrar sesión' : 'Cancelar'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Requisito extends StatelessWidget {
  const _Requisito({required this.texto, required this.cumplido});

  final String texto;
  final bool cumplido;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            cumplido ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 18,
            color: cumplido ? esquema.primary : esquema.outline,
            semanticLabel: cumplido ? 'Cumplido' : 'Pendiente',
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(texto, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

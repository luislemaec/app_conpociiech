import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/api/cliente_api.dart';
import '../../../shared/tema/colores_semanticos.dart';
import '../../../shared/tema/diseno_app.dart';
import '../../../shared/widgets/estructura_adaptativa.dart';
import '../../../shared/widgets/etiquetas.dart';
import '../api_tribunal.dart';
import '../widgets_tribunal.dart';

/// Lo que «Datos de la persona» devuelve a la lista de miembros.
sealed class ResultadoMiembro {
  const ResultadoMiembro();
}

/// Se agregó o se guardó el miembro.
final class MiembroGuardado extends ResultadoMiembro {
  const MiembroGuardado(this.detalle, {this.nuevo = false});

  final MiembroDetalle detalle;
  final bool nuevo;
}

/// El miembro se dio de baja.
final class MiembroDadoDeBaja extends ResultadoMiembro {
  const MiembroDadoDeBaja(this.id);

  final int id;
}

/// «Datos de la persona» (IglesiaAdmin): los campos del diálogo de Personas de TEC WEB
/// («Apellidos y Nombres», cédula, sexo) y «Habilitar para padrón». Consulta el detalle
/// actualizado a TEC y, al guardar, devuelve el miembro a la lista. Los datos de la
/// persona y la habilitación son cambios distintos: TEC guarda cada uno con su servicio
/// (ver `GestionMovilService.actualizarPersonaMiembro`) y valida alcance, cronograma,
/// cédula e iglesia activa. Desde aquí también se da de baja al miembro.
class PantallaEditarMiembro extends StatelessWidget {
  const PantallaEditarMiembro({super.key, required this.miembroId});

  final int miembroId;

  @override
  Widget build(BuildContext context) {
    final api = context.read<ApiTribunal>();
    return EstructuraAdaptativa(
      appBar: AppBar(title: const Text('Datos de la persona')),
      body: VistaConsulta<MiembroDetalle>(
        cargar: () => api.detalleMiembro(miembroId),
        construir: (context, detalle) =>
            _Formulario(key: ValueKey(detalle), detalle: detalle),
      ),
    );
  }
}

/// Agregar una persona a la iglesia del usuario, como «Nuevo» en Personas de TEC WEB:
/// mismos campos, habilitada para el padrón por defecto. TEC valida todo al guardar.
class PantallaNuevoMiembro extends StatelessWidget {
  const PantallaNuevoMiembro({super.key});

  @override
  Widget build(BuildContext context) => EstructuraAdaptativa(
    appBar: AppBar(title: const Text('Agregar persona')),
    body: const _Formulario(detalle: null),
  );
}

class _Formulario extends StatefulWidget {
  const _Formulario({super.key, required this.detalle});

  /// null = persona nueva.
  final MiembroDetalle? detalle;

  @override
  State<_Formulario> createState() => _FormularioState();
}

class _FormularioState extends State<_Formulario> {
  static const int _largoNombres = 100;

  final _formulario = GlobalKey<FormState>();
  late final _nombres = TextEditingController(text: widget.detalle?.nombres);
  late final _documento = TextEditingController(
    text: widget.detalle?.documento,
  );
  late final _sexo = ValueNotifier<String?>(widget.detalle?.sexo);
  // Como en la web, una persona nueva queda habilitada salvo que se desmarque.
  late final _habilitado = ValueNotifier<bool>(
    widget.detalle?.habilitado ?? true,
  );
  bool _guardando = false;
  String? _error;

  /// Cualquier cambio del formulario: solo reconstruye lo que depende de él (botón).
  late final Listenable _cambios = Listenable.merge([
    _nombres,
    _documento,
    _sexo,
    _habilitado,
  ]);

  bool get _nuevo => widget.detalle == null;

  /// Una persona nueva siempre se puede escribir: TEC rechaza el alta fuera del cronograma.
  bool get _editable => (widget.detalle?.permiteEdicion ?? true) && !_guardando;

  bool get _cambiaPersona {
    final d = widget.detalle;
    if (d == null) return true;
    return _nombres.text.trim() != d.nombres.trim() ||
        _documento.text.trim() != d.documento.trim() ||
        _sexo.value != d.sexo;
  }

  bool get _cambiaHabilitacion =>
      _nuevo || _habilitado.value != widget.detalle!.habilitado;

  @override
  void dispose() {
    // Nada del formulario sobrevive al salir de la pantalla.
    _nombres.dispose();
    _documento.dispose();
    _sexo.dispose();
    _habilitado.dispose();
    super.dispose();
  }

  void _avisar(String texto) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(texto)));

  /// Ejecuta una operación en TEC y muestra en el formulario el mensaje de TEC si falla.
  Future<void> _enTec(Future<void> Function(ApiTribunal api) operacion) async {
    final api = context.read<ApiTribunal>();
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await operacion(api);
    } on ErrorApi catch (e) {
      // Reglas de TEC (cédula duplicada, otra iglesia, cronograma cerrado…): su mensaje.
      if (mounted) setState(() => _error = e.mensaje);
    } catch (e) {
      if (mounted) setState(() => _error = mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    if (!(_cambiaPersona || _cambiaHabilitacion)) return;
    if (!(_formulario.currentState?.validate() ?? false)) return;
    await _enTec((api) async {
      final MiembroDetalle guardado;
      if (_nuevo) {
        guardado = await api.crearMiembro(
          nombres: _nombres.text.trim(),
          documento: _documento.text.trim(),
          sexo: _sexo.value,
          habilitado: _habilitado.value,
        );
      } else {
        guardado = await api.actualizarPersona(
          widget.detalle!.id,
          nombres: _nombres.text.trim(),
          documento: _documento.text.trim(),
          sexo: _sexo.value,
          // Solo se envía si cambió: TEC no toca la habilitación en caso contrario.
          habilitado: _cambiaHabilitacion ? _habilitado.value : null,
        );
      }
      if (!mounted) return;
      _avisar(
        _nuevo
            ? 'Persona agregada a la iglesia.'
            : 'Datos de la persona actualizados.',
      );
      context.pop(MiembroGuardado(guardado, nuevo: _nuevo));
    });
  }

  /// Baja lógica, como la papelera de TEC WEB: el registro queda en el historial.
  Future<void> _darDeBaja() async {
    final detalle = widget.detalle!;
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.person_remove_outlined),
        title: const Text('Dar de baja'),
        content: Text(
          '¿Está seguro de eliminar a ${detalle.nombre} de la iglesia? '
          'El registro será dado de baja.\n\n'
          'Si ya consta en el padrón o en una junta receptora del voto, dejará de '
          'aparecer en el padrón. El historial se conserva y solo el Tribunal o el '
          'Administrador pueden restaurarlo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Dar de baja'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;
    await _enTec((api) async {
      await api.darDeBajaMiembro(detalle.id);
      if (!mounted) return;
      _avisar('${detalle.nombre} fue dado de baja.');
      context.pop(MiembroDadoDeBaja(detalle.id));
    });
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final detalle = widget.detalle;
    return Form(
      key: _formulario,
      child: ContenidoConsulta(
        children: [
          if (detalle != null) ...[
            Text(detalle.nombre, style: tema.textTheme.titleLarge),
            const SizedBox(height: DisenoApp.sm),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                EtiquetaPadron(habilitado: detalle.habilitado),
                if (detalle.revisado)
                  const EtiquetaSemantica(
                    texto: 'Información revisada',
                    tono: TonoSemantico.exito,
                    icono: Icons.verified_outlined,
                  )
                else
                  const EtiquetaPendienteRevision(),
              ],
            ),
            const SizedBox(height: DisenoApp.md),
            if (!detalle.permiteEdicion) ...[
              const AvisoSemantico(
                'Los datos solo se pueden modificar en la fase del cronograma que permite '
                'editar el padrón.',
                tono: TonoSemantico.advertencia,
              ),
              const SizedBox(height: DisenoApp.md),
            ],
          ] else ...[
            Text(
              'La persona se agregará a su iglesia. TEC verifica la cédula y que no '
              'pertenezca a otra iglesia.',
              style: tema.textTheme.bodyMedium,
            ),
            const SizedBox(height: DisenoApp.md),
          ],
          _Seccion(
            titulo: 'Datos personales',
            children: [
              TextFormField(
                controller: _nombres,
                enabled: _editable,
                textCapitalization: TextCapitalization.characters,
                maxLength: _largoNombres,
                decoration: const InputDecoration(
                  labelText: 'Apellidos y nombres',
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Ingrese los apellidos y nombres.'
                    : null,
              ),
              const SizedBox(height: DisenoApp.sm),
              TextFormField(
                controller: _documento,
                enabled: _editable,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 10,
                decoration: const InputDecoration(
                  labelText: 'Cédula',
                  helperText:
                      'TEC verifica el dígito verificador y que no pertenezca a otra persona.',
                  helperMaxLines: 2,
                ),
                // El formato se revisa aquí; el dígito verificador y los duplicados, en
                // TEC (mismas reglas que la web, sin duplicarlas en la App).
                validator: (v) {
                  final valor = v?.trim() ?? '';
                  if (valor.isEmpty) return 'Ingrese la cédula.';
                  if (detalle != null && valor == detalle.documento.trim()) {
                    return null; // sin cambio
                  }
                  if (!RegExp(r'^\d{10}$').hasMatch(valor)) {
                    return 'La cédula debe tener 10 dígitos.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: DisenoApp.sm),
              Text('Sexo', style: tema.textTheme.labelLarge),
              const SizedBox(height: DisenoApp.sm),
              // Chips con ícono + texto: se acomodan en varias líneas sin cortar palabras.
              ValueListenableBuilder<String?>(
                valueListenable: _sexo,
                builder: (context, sexo, _) => Wrap(
                  spacing: DisenoApp.sm,
                  runSpacing: DisenoApp.sm,
                  children: [
                    for (final valor in const ['M', 'F', null])
                      ChoiceChip(
                        avatar: Icon(Sexo.icono(valor), size: 20),
                        label: Text(Sexo.texto(valor)),
                        showCheckmark: false,
                        selected: sexo == valor,
                        onSelected: _editable
                            ? (_) => _sexo.value = valor
                            : null,
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: DisenoApp.md),
          _Seccion(
            titulo: 'Padrón electoral',
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: _habilitado,
                builder: (context, habilitado, _) => SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Habilitar para padrón'),
                  subtitle: Text(
                    habilitado
                        ? 'Puede participar en las elecciones.'
                        : 'No participará en las elecciones.',
                  ),
                  value: habilitado,
                  onChanged: _editable ? (v) => _habilitado.value = v : null,
                ),
              ),
              Text(
                _nuevo
                    ? 'La persona queda registrada como revisada.'
                    : 'Guardar cambios en la habilitación o en los datos marca al miembro como revisado.',
                style: tema.textTheme.bodySmall,
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: DisenoApp.md),
            AvisoSemantico(_error!, tono: TonoSemantico.peligro),
          ],
          const SizedBox(height: DisenoApp.lg),
          ListenableBuilder(
            listenable: _cambios,
            builder: (context, _) => FilledButton.icon(
              onPressed: _editable && (_cambiaPersona || _cambiaHabilitacion)
                  ? _guardar
                  : null,
              icon: _guardando
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _nuevo
                          ? Icons.person_add_alt_1_outlined
                          : Icons.save_outlined,
                    ),
              label: Text(
                _guardando
                    ? 'Guardando…'
                    : (_nuevo ? 'Agregar persona' : 'Guardar cambios'),
              ),
            ),
          ),
          if (detalle != null) ...[
            const SizedBox(height: DisenoApp.xl),
            const Divider(),
            const SizedBox(height: DisenoApp.sm),
            Text(
              'La baja quita a la persona de la iglesia y del padrón; no borra su historial.',
              style: tema.textTheme.bodySmall,
            ),
            const SizedBox(height: DisenoApp.sm),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: tema.colorScheme.error,
                side: BorderSide(color: tema.colorScheme.error),
              ),
              onPressed: _editable ? _darDeBaja : null,
              icon: const Icon(Icons.person_remove_outlined),
              label: const Text('Dar de baja'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Grupo del formulario con título, sin tarjeta adicional.
class _Seccion extends StatelessWidget {
  const _Seccion({required this.titulo, required this.children});

  final String titulo;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(titulo, style: Theme.of(context).textTheme.titleMedium),
        ),
        const SizedBox(height: DisenoApp.sm),
        ...children,
      ],
    );
  }
}

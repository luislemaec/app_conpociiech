import 'package:flutter/material.dart';
import '../../../shared/widgets/estructura_adaptativa.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/api/cliente_api.dart';
import '../api_tribunal.dart';
import 'guia_escrutinio.dart';
import '../../../shared/widgets/estados_app.dart';
import '../widgets_tribunal.dart';

/// Obtiene la foto del acta (JPEG) desde la cámara o la galería; `null` si se cancela.
typedef SelectorFoto = Future<List<int>?> Function(ImageSource origen);

/// Selector real: re-codifica a JPEG (calidad 85, máx. 2400 px) para cumplir el límite de TEC.
Future<List<int>?> seleccionarFotoActa(ImageSource origen) async {
  final foto = await ImagePicker().pickImage(
    source: origen,
    imageQuality: 85,
    maxWidth: 2400,
    maxHeight: 2400,
  );
  return foto == null ? null : await foto.readAsBytes();
}

/// Escrutinio de la mesa del Presidente: apertura, conteo, cierre y foto del acta física.
/// Solo en línea: cada paso se guarda en TEC, que valida de nuevo todas las reglas.
class PantallaEscrutinio extends StatefulWidget {
  const PantallaEscrutinio({
    super.key,
    this.selectorFoto = seleccionarFotoActa,
  });

  final SelectorFoto selectorFoto;

  @override
  State<PantallaEscrutinio> createState() => _PantallaEscrutinioState();
}

class _PantallaEscrutinioState extends State<PantallaEscrutinio> {
  static const int _tamanoMaximo = 10 * 1024 * 1024;

  ActaPresidente? _acta;
  String? _error;
  bool _procesando = false;
  bool _modificado = false;
  final Map<int, TextEditingController> _campos = {};
  final _observacion = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    for (final c in _campos.values) {
      c.dispose();
    }
    _observacion.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _error = null);
    try {
      _aplicar(await context.read<ApiTribunal>().acta());
    } catch (e) {
      if (mounted) setState(() => _error = mensajeDeError(e));
    }
  }

  void _aplicar(ActaPresidente acta) {
    if (!mounted) return;
    setState(() {
      _acta = acta;
      _modificado = false;
      for (final c in acta.categorias) {
        (_campos[c.categoriaId] ??= TextEditingController()).text =
            '${c.votos}';
      }
    });
  }

  /// Votos escritos en pantalla; `null` si alguno está vacío o no es un número válido.
  Map<int, int>? get _votos {
    final votos = <int, int>{};
    for (final c in _acta?.categorias ?? const <CategoriaConteo>[]) {
      final valor = int.tryParse(_campos[c.categoriaId]?.text.trim() ?? '');
      if (valor == null || valor < 0 || valor > 100000) return null;
      votos[c.categoriaId] = valor;
    }
    return votos;
  }

  ({int emitidos, int papeletas, int cuadre})? get _totales {
    final votos = _votos;
    final acta = _acta;
    if (votos == null || acta == null) return null;
    var emitidos = 0;
    var papeletas = 0;
    for (final c in acta.categorias) {
      if (c.papeletas) {
        papeletas += votos[c.categoriaId]!;
      } else {
        emitidos += votos[c.categoriaId]!;
      }
    }
    return (
      emitidos: emitidos,
      papeletas: papeletas,
      cuadre: acta.sufragantes - emitidos - papeletas,
    );
  }

  /// Ejecuta un paso en TEC, muestra el resultado y refresca el acta.
  Future<void> _ejecutar(
    Future<ActaPresidente> Function(ApiTribunal api) paso,
    String exito,
  ) async {
    final api = context.read<ApiTribunal>();
    final mensajes = ScaffoldMessenger.of(context);
    setState(() => _procesando = true);
    String aviso = exito;
    try {
      _aplicar(await paso(api));
    } on ErrorApi catch (e) {
      aviso = e.mensaje;
      await _cargar();
    } catch (e) {
      aviso = mensajeDeError(e);
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
    _avisar(mensajes, aviso);
  }

  /// Reemplaza el aviso visible en lugar de encolarlo detrás del anterior.
  static void _avisar(ScaffoldMessengerState mensajes, String texto) => mensajes
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(texto)));

  Future<bool> _confirmar(String titulo, String texto, String accion) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(titulo),
          content: Text(texto),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(accion),
            ),
          ],
        ),
      ) ==
      true;

  Future<void> _abrir() async {
    if (!await _confirmar(
      'Registrar apertura',
      '¿Registrar la apertura de la mesa ahora?',
      'Registrar apertura',
    )) {
      return;
    }
    await _ejecutar(
      (api) => api.abrirMesa(_observacion.text),
      'Apertura de la mesa registrada.',
    );
  }

  Future<void> _guardar() async {
    final votos = _votos;
    if (votos == null) return;
    await _ejecutar((api) => api.guardarConteo(votos), 'Conteo guardado.');
  }

  Future<void> _cerrar() async {
    final votos = _votos;
    final totales = _totales;
    if (votos == null || totales == null) return;
    final aviso = totales.cuadre == 0
        ? 'Las papeletas cuadran con los sufragantes.'
        : 'Atención: el cuadre de papeletas es ${totales.cuadre} (debería ser 0).';
    if (!await _confirmar(
      'Cerrar la mesa',
      'Votos emitidos: ${totales.emitidos}. Papeletas no utilizadas: ${totales.papeletas}. $aviso\n\n'
          'Después de cerrar, el conteo ya no se puede modificar.',
      'Cerrar mesa',
    )) {
      return;
    }
    await _ejecutar(
      (api) => api.cerrarMesa(votos),
      'Mesa cerrada. Suba la foto del acta física firmada.',
    );
  }

  Future<void> _subirFoto(ImageSource origen) async {
    final mensajes = ScaffoldMessenger.of(context);
    final List<int>? foto;
    try {
      foto = await widget.selectorFoto(origen);
    } catch (_) {
      _avisar(
        mensajes,
        'No se pudo obtener la foto. Revise los permisos de la cámara.',
      );
      return;
    }
    if (foto == null || !mounted) return;
    if (foto.length < 3 ||
        foto[0] != 0xFF ||
        foto[1] != 0xD8 ||
        foto[2] != 0xFF) {
      _avisar(mensajes, 'La foto debe estar en formato JPEG.');
      return;
    }
    if (foto.length > _tamanoMaximo) {
      _avisar(
        mensajes,
        'La foto supera los 10 MB. Tómela con menos resolución.',
      );
      return;
    }
    await _ejecutar(
      (api) => api.subirActaFisica(foto!),
      'Foto del acta enviada para revisión del Tribunal.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final acta = _acta;
    return EstructuraAdaptativa(
      appBar: AppBar(title: const Text('Escrutinio de la mesa')),
      body: acta == null
          ? (_error == null
                ? const EstadoCarga()
                : EstadoError(mensaje: _error!, reintentar: _cargar))
          : AbsorbPointer(
              absorbing: _procesando,
              child: RefreshIndicator(
                onRefresh: _cargar,
                child: ContenidoConsulta(
                  children: [
                    if (_error != null)
                      EstadoError(mensaje: _error!, reintentar: _cargar),
                    if (_procesando) const LinearProgressIndicator(),
                    _cabecera(acta),
                    GuiaEscrutinio(acta: acta, modificado: _modificado),
                    if (acta.estado == 'PENDIENTE') _apertura(acta),
                    if (acta.estado != 'PENDIENTE') _conteo(acta),
                    if (acta.cerrada) _actaFisica(acta),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _cabecera(ActaPresidente acta) => Seccion(
    titulo: acta.ubicacion.mesa,
    children: [
      Align(
        alignment: Alignment.centerLeft,
        child: EtiquetaEstado(acta.estado),
      ),
      const SizedBox(height: 12),
      Dato('Recinto', acta.ubicacion.recinto),
      Dato('Sufragantes', formatoNumero(acta.sufragantes)),
    ],
  );

  Widget _apertura(ActaPresidente acta) => Seccion(
    titulo: 'Apertura',
    children: [
      if (acta.puedeAbrir) ...[
        TextField(
          controller: _observacion,
          maxLength: 500,
          decoration: const InputDecoration(
            labelText: 'Observación (opcional)',
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _abrir,
          icon: const Icon(Icons.lock_open),
          label: const Text('Registrar apertura'),
        ),
      ] else
        Text(
          acta.motivoBloqueoApertura ?? 'La mesa todavía no se puede abrir.',
        ),
    ],
  );

  Widget _conteo(ActaPresidente acta) {
    final totales = _totales;
    final editable = acta.puedeEditarConteo;
    final tema = Theme.of(context);
    return Seccion(
      titulo: 'Conteo de votos',
      children: [
        for (final c in acta.categorias)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextField(
              key: ValueKey('categoria-${c.categoriaId}'),
              controller: _campos[c.categoriaId],
              enabled: editable,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              decoration: InputDecoration(
                labelText: c.nombre,
                helperText: c.papeletas ? 'No cuenta como voto' : null,
              ),
              onChanged: (_) => setState(() => _modificado = true),
            ),
          ),
        const Divider(),
        if (totales == null)
          Text(
            'Ingrese un número en cada categoría.',
            style: TextStyle(color: tema.colorScheme.error),
          )
        else ...[
          Dato('Votos emitidos', formatoNumero(totales.emitidos)),
          Dato('Papeletas no utilizadas', formatoNumero(totales.papeletas)),
          Dato(
            'Cuadre',
            totales.cuadre == 0
                ? '0 (cuadrado)'
                : '${totales.cuadre} (no cuadra)',
          ),
        ],
        if (acta.observacionConteo != null &&
            acta.observacionConteo!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(acta.observacionConteo!, style: tema.textTheme.bodySmall),
        ],
        if (editable) ...[
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _modificado && totales != null ? _guardar : null,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Guardar conteo'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: acta.puedeCerrar && !_modificado && totales != null
                ? _cerrar
                : null,
            icon: const Icon(Icons.lock_outline),
            label: const Text('Cerrar mesa'),
          ),
          if (_modificado)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Guarde el conteo antes de cerrar la mesa.',
                style: tema.textTheme.bodySmall,
              ),
            ),
        ],
      ],
    );
  }

  Widget _actaFisica(ActaPresidente acta) => Seccion(
    titulo: 'Acta física',
    children: [
      if (acta.actaFisica case final a?) ...[
        Dato('Estado', a.etiqueta),
        if (a.version != null) Dato('Versión', '${a.version}'),
        if (a.observacion != null && a.observacion!.isNotEmpty)
          Dato('Observación', a.observacion),
      ] else
        const Text('Aún no se ha enviado la foto del acta firmada.'),
      if (acta.puedeSubirActaFisica) ...[
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => _subirFoto(ImageSource.camera),
          icon: const Icon(Icons.photo_camera_outlined),
          label: Text(
            acta.actaFisica == null
                ? 'Tomar foto del acta'
                : 'Enviar otra foto',
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _subirFoto(ImageSource.gallery),
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text('Elegir de la galería'),
        ),
      ],
    ],
  );
}

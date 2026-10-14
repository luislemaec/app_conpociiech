import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../../../shared/widgets/estructura_adaptativa.dart';
import 'package:provider/provider.dart';

import '../../../core/api/cliente_api.dart';
import '../api_tribunal.dart';
import '../../../shared/widgets/estados_app.dart';
import '../widgets_tribunal.dart';

/// Detalle de una mesa para Administrador y Tribunal: junta, conteo, cuadre y revisión del
/// acta física (ver la foto, validarla como dato oficial, u observarla/rechazarla con motivo).
class PantallaDetalleMesa extends StatefulWidget {
  const PantallaDetalleMesa({super.key, required this.mesaId});

  final int mesaId;

  @override
  State<PantallaDetalleMesa> createState() => _PantallaDetalleMesaState();
}

class _PantallaDetalleMesaState extends State<PantallaDetalleMesa> {
  DetalleMesa? _mesa;
  String? _error;
  bool _procesando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _error = null);
    try {
      final mesa = await context.read<ApiTribunal>().detalleMesa(widget.mesaId);
      if (mounted) setState(() => _mesa = mesa);
    } catch (e) {
      if (mounted) setState(() => _error = mensajeDeError(e));
    }
  }

  Future<void> _revisar(
    Future<DetalleMesa> Function(ApiTribunal api) accion,
    String exito,
  ) async {
    final api = context.read<ApiTribunal>();
    final mensajes = ScaffoldMessenger.of(context);
    setState(() => _procesando = true);
    var aviso = exito;
    try {
      final mesa = await accion(api);
      if (mounted) setState(() => _mesa = mesa);
    } on ErrorApi catch (e) {
      aviso = e.mensaje;
      await _cargar();
    } catch (e) {
      aviso = mensajeDeError(e);
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
    mensajes
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(aviso)));
  }

  /// Validar exige marcar el cotejo, igual que «Marcar como datos oficiales» en la web.
  Future<void> _validar() async {
    var cotejo = false;
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, actualizar) => AlertDialog(
          title: const Text('Validar el acta física'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Los votos registrados por el Presidente pasarán a ser el dato oficial de la mesa.',
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: cotejo,
                onChanged: (v) => actualizar(() => cotejo = v ?? false),
                title: const Text(
                  'Confirmo que el acta física coincide con lo registrado.',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: cotejo ? () => Navigator.pop(context, true) : null,
              child: const Text('Validar'),
            ),
          ],
        ),
      ),
    );
    if (confirmado != true) return;
    await _revisar(
      (api) => api.validarActa(widget.mesaId),
      'Acta validada: los datos de la mesa son oficiales.',
    );
  }

  /// Observar o rechazar exige un motivo; la mesa vuelve al Presidente para corregir.
  Future<void> _devolver({required bool rechazar}) async {
    final texto = await showDialog<String>(
      context: context,
      builder: (_) => _DialogoMotivo(rechazar: rechazar),
    );
    if (texto == null) return;
    await _revisar(
      (api) =>
          api.devolverActa(widget.mesaId, rechazar: rechazar, motivo: texto),
      rechazar
          ? 'Acta rechazada. La mesa volvió al Presidente.'
          : 'Acta observada. La mesa volvió al Presidente.',
    );
  }

  void _verFoto() {
    final api = context.read<ApiTribunal>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _VisorActa(
          cargar: () => api.fotoActa(widget.mesaId),
          titulo: _mesa?.ubicacion.mesa ?? 'Acta',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mesa = _mesa;
    return EstructuraAdaptativa(
      appBar: AppBar(title: Text(mesa?.ubicacion.mesa ?? 'Mesa')),
      body: mesa == null
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
                    Seccion(
                      titulo: mesa.ubicacion.mesa,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            EtiquetaEstado(mesa.estado),
                            if (mesa.fase != null) EtiquetaFase(mesa.fase!),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Dato('Recinto', mesa.ubicacion.recinto),
                        Dato('Ubicación', mesa.ubicacion.lugar),
                        Dato('Electores', formatoNumero(mesa.electores)),
                        if (mesa.fechaApertura != null)
                          Dato('Apertura', formatoFecha(mesa.fechaApertura)),
                        if (mesa.fechaCierre != null)
                          Dato('Cierre', formatoFecha(mesa.fechaCierre)),
                      ],
                    ),
                    Seccion(
                      titulo: 'Junta Receptora del Voto',
                      children: [
                        if (mesa.junta.isEmpty)
                          const Text('Sin miembros designados.'),
                        for (final m in mesa.junta)
                          Dato(m.cargo ?? 'Miembro', m.nombre),
                      ],
                    ),
                    Seccion(
                      titulo: 'Conteo',
                      children: [
                        if (mesa.conteo.isEmpty)
                          const Text('Aún no hay conteo registrado.'),
                        for (final c in mesa.conteo)
                          Dato(c.categoria, formatoNumero(c.votos)),
                        if (mesa.cuadre != null)
                          Dato(
                            'Cuadre',
                            mesa.cuadre == 0
                                ? '0 (cuadrado)'
                                : '${mesa.cuadre} (no cuadra)',
                          ),
                        if (mesa.observacionConteo != null &&
                            mesa.observacionConteo!.isNotEmpty)
                          Text(
                            mesa.observacionConteo!,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                    Seccion(
                      titulo: 'Acta física',
                      children: [
                        if (mesa.actaFisica case final a?) ...[
                          Dato('Estado', a.etiqueta),
                          if (a.version != null)
                            Dato('Versión', '${a.version}'),
                          if (a.observacion != null &&
                              a.observacion!.isNotEmpty)
                            Dato('Observación', a.observacion),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _verFoto,
                            icon: const Icon(Icons.image_outlined),
                            label: const Text('Ver foto del acta'),
                          ),
                        ] else
                          const Text(
                            'El Presidente aún no ha enviado la foto del acta.',
                          ),
                        if (mesa.puedeRevisarActa) ...[
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _validar,
                            icon: const Icon(Icons.verified_outlined),
                            label: const Text('Validar como dato oficial'),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () => _devolver(rechazar: false),
                            icon: const Icon(Icons.rate_review_outlined),
                            label: const Text('Observar'),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () => _devolver(rechazar: true),
                            icon: const Icon(Icons.block_outlined),
                            label: const Text('Rechazar'),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// Pide el motivo (obligatorio) para observar o rechazar; devuelve el texto o `null`.
/// Es dueño de su controlador: lo libera al desmontarse, después de la animación de cierre.
class _DialogoMotivo extends StatefulWidget {
  const _DialogoMotivo({required this.rechazar});

  final bool rechazar;

  @override
  State<_DialogoMotivo> createState() => _DialogoMotivoState();
}

class _DialogoMotivoState extends State<_DialogoMotivo> {
  final _motivo = TextEditingController();

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final texto = _motivo.text.trim();
    return AlertDialog(
      title: Text(widget.rechazar ? 'Rechazar el acta' : 'Observar el acta'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'La mesa volverá al Presidente para que corrija el conteo y envíe una nueva foto.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _motivo,
              maxLength: 500,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Motivo (obligatorio)',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: texto.isEmpty ? null : () => Navigator.pop(context, texto),
          child: Text(widget.rechazar ? 'Rechazar' : 'Observar'),
        ),
      ],
    );
  }
}

/// Foto del acta a pantalla completa, con zoom para leer los valores.
class _VisorActa extends StatelessWidget {
  const _VisorActa({required this.cargar, required this.titulo});

  final Future<List<int>> Function() cargar;
  final String titulo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Acta · $titulo')),
      backgroundColor: Colors.black,
      body: VistaConsulta<List<int>>(
        cargar: cargar,
        construir: (context, bytes) => InteractiveViewer(
          maxScale: 6,
          child: Center(
            child: Image.memory(
              Uint8List.fromList(bytes),
              semanticLabel: 'Foto del acta física',
              errorBuilder: (_, _, _) => const Text(
                'No se pudo mostrar la imagen.',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

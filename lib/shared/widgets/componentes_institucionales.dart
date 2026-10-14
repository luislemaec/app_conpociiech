import 'package:flutter/material.dart';

import '../tema/colores_tribunal.dart';
import '../tema/diseno_app.dart';

/// Componentes de las pantallas institucionales (Inicio, Organización, Servicios),
/// adaptados de app_consejo (`EncabezadoInstitucional`, `SeccionCard`,
/// `ServicioDestacadoCard`, `ContentLimiter`) a los colores del Tribunal.

/// Centra el contenido y limita su ancho en tablets para no estirar líneas ni tarjetas.
class ContenidoLimitado extends StatelessWidget {
  const ContenidoLimitado({
    super.key,
    required this.child,
    this.anchoMaximo = DisenoApp.anchoLectura,
  });

  final Widget child;
  final double anchoMaximo;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: anchoMaximo),
        child: child,
      ),
    );
  }
}

/// Encabezado de pantalla: ícono, título y descripción, plano (sin degradado ni sombra).
class EncabezadoInstitucional extends StatelessWidget {
  const EncabezadoInstitucional({
    super.key,
    required this.icono,
    required this.titulo,
    required this.descripcion,
  });

  final IconData icono;
  final String titulo;
  final String descripcion;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DisenoApp.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: DisenoApp.minimoTactil,
            height: DisenoApp.minimoTactil,
            decoration: BoxDecoration(
              color: ColoresTribunal.primario50,
              borderRadius: BorderRadius.circular(DisenoApp.radioIcono),
            ),
            child: Icon(icono, color: ColoresTribunal.primario),
          ),
          const SizedBox(width: DisenoApp.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(titulo, style: texto.titleLarge),
                ),
                const SizedBox(height: DisenoApp.xs),
                Text(descripcion, style: texto.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta de sección: encabezado (ícono + título en mayúsculas) y contenido.
class SeccionCard extends StatelessWidget {
  const SeccionCard({
    super.key,
    required this.icono,
    required this.titulo,
    required this.children,
  });

  final IconData icono;
  final String titulo;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(DisenoApp.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: ColoresTribunal.primario50,
                    borderRadius: BorderRadius.circular(DisenoApp.sm),
                  ),
                  child: Icon(icono, size: 20, color: ColoresTribunal.primario),
                ),
                const SizedBox(width: DisenoApp.sm + DisenoApp.xs),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      titulo,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: ColoresTribunal.azulInstitucional,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: DisenoApp.md),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Acceso a un servicio o sección: ícono, título, descripción y flecha. Se reduce
/// levemente al presionarlo. Sin [alTocar] se muestra como informativa (sin flecha).
class TarjetaServicio extends StatefulWidget {
  const TarjetaServicio({
    super.key,
    required this.icono,
    required this.titulo,
    required this.descripcion,
    this.alTocar,
    this.destacada = false,
    this.etiqueta,
  });

  final IconData icono;
  final String titulo;
  final String descripcion;
  final VoidCallback? alTocar;
  final bool destacada;

  /// Texto breve opcional (p. ej. «Requiere iniciar sesión»).
  final String? etiqueta;

  @override
  State<TarjetaServicio> createState() => _TarjetaServicioState();
}

class _TarjetaServicioState extends State<TarjetaServicio> {
  bool _presionada = false;

  void _presionar(bool valor) {
    if (_presionada != valor) setState(() => _presionada = valor);
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final destacada = widget.destacada;
    final activa = widget.alTocar != null;

    return Semantics(
      button: activa,
      child: AnimatedScale(
        scale: _presionada ? 0.98 : 1,
        duration: DisenoApp.rapida,
        child: Material(
          color: destacada
              ? ColoresTribunal.primario50
              : ColoresTribunal.superficie,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DisenoApp.radio),
            side: BorderSide(
              color: destacada
                  ? ColoresTribunal.primario
                  : ColoresTribunal.borde,
              width: destacada ? 1.4 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.alTocar,
            onTapDown: activa ? (_) => _presionar(true) : null,
            onTapCancel: activa ? () => _presionar(false) : null,
            onTapUp: activa ? (_) => _presionar(false) : null,
            child: Padding(
              padding: const EdgeInsets.all(DisenoApp.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: DisenoApp.minimoTactil,
                    height: DisenoApp.minimoTactil,
                    decoration: BoxDecoration(
                      color: destacada
                          ? ColoresTribunal.primario
                          : ColoresTribunal.primario100,
                      borderRadius: BorderRadius.circular(DisenoApp.radioIcono),
                    ),
                    child: Icon(
                      widget.icono,
                      color: destacada
                          ? ColoresTribunal.sobreColor
                          : ColoresTribunal.primario800,
                    ),
                  ),
                  const SizedBox(width: DisenoApp.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.titulo,
                          style: tema.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: DisenoApp.xs),
                        Text(
                          widget.descripcion,
                          style: tema.textTheme.bodyMedium?.copyWith(
                            height: 1.4,
                          ),
                        ),
                        if (widget.etiqueta != null) ...[
                          const SizedBox(height: DisenoApp.sm),
                          Text(
                            widget.etiqueta!,
                            style: tema.textTheme.labelMedium?.copyWith(
                              color: ColoresTribunal.primario,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (activa) ...[
                    const SizedBox(width: DisenoApp.sm),
                    const ExcludeSemantics(
                      child: Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          size: 20,
                          color: ColoresTribunal.primario,
                        ),
                      ),
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

/// Fila informativa dentro de una sección (sin tarjeta propia): ícono, título y texto.
/// Para listas de contenido de solo lectura, separadas con [Divider].
class FilaInformativa extends StatelessWidget {
  const FilaInformativa({
    super.key,
    required this.icono,
    required this.titulo,
    required this.descripcion,
  });

  final IconData icono;
  final String titulo;
  final String descripcion;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DisenoApp.sm + DisenoApp.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icono, size: 22, color: ColoresTribunal.primario),
            ),
          ),
          const SizedBox(width: DisenoApp.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: texto.titleMedium),
                const SizedBox(height: DisenoApp.xs),
                Text(descripcion, style: texto.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Separación vertical estándar entre bloques de una pantalla institucional.
const SizedBox separacionBloque = SizedBox(height: DisenoApp.md);

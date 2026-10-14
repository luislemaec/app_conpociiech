import 'package:flutter/material.dart';

import '../tema/colores_tribunal.dart';
import '../tema/diseno_app.dart';

/// Componentes de las pantallas institucionales (Inicio, Organización, Servicios),
/// adaptados de app_consejo (`EncabezadoInstitucional`, `SeccionCard`,
/// `ServicioDestacadoCard`, `ContentLimiter`) a los colores del Tribunal.

/// Degradado institucional: solo tokens de [ColoresTribunal].
const LinearGradient degradadoInstitucional = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [ColoresTribunal.primario800, ColoresTribunal.primario],
);

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

/// Encabezado de sección principal: bloque con degradado azul, ícono, título y texto.
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
    return Container(
      padding: const EdgeInsets.all(DisenoApp.lg),
      decoration: BoxDecoration(
        gradient: degradadoInstitucional,
        borderRadius: BorderRadius.circular(DisenoApp.radio),
        boxShadow: [
          BoxShadow(
            color: ColoresTribunal.primario800.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: ColoresTribunal.sobreColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(DisenoApp.radioIcono),
              border: Border.all(
                color: ColoresTribunal.sobreColor.withValues(alpha: 0.18),
              ),
            ),
            child: Icon(icono, color: ColoresTribunal.sobreColor),
          ),
          const SizedBox(height: DisenoApp.md),
          Text(
            titulo,
            style: texto.titleLarge?.copyWith(
              color: ColoresTribunal.sobreColor,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          const SizedBox(height: DisenoApp.sm),
          Text(
            descripcion,
            style: texto.bodyMedium?.copyWith(
              color: ColoresTribunal.sobreColor.withValues(alpha: 0.9),
              height: 1.45,
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
                      titulo.toUpperCase(),
                      style: const TextStyle(
                        color: ColoresTribunal.azulInstitucional,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
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

/// Separación vertical estándar entre bloques de una pantalla institucional.
const SizedBox separacionBloque = SizedBox(height: DisenoApp.md);

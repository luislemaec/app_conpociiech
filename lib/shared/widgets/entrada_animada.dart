import 'package:flutter/material.dart';

import '../tema/diseno_app.dart';

/// Entrada suave (aparece y sube levemente) la primera vez que se muestra el widget.
/// Basado en `EntradaAnimada` de app_consejo. El retardo se resuelve dentro de la
/// propia animación (sin temporizadores) y se omite si el sistema pide reducir
/// animaciones.
class EntradaAnimada extends StatefulWidget {
  const EntradaAnimada({
    super.key,
    required this.child,
    this.retardo = Duration.zero,
    this.duracion = DisenoApp.entrada,
  });

  final Widget child;

  /// Retardo antes de empezar; útil para una entrada escalonada.
  final Duration retardo;
  final Duration duracion;

  @override
  State<EntradaAnimada> createState() => _EntradaAnimadaState();
}

class _EntradaAnimadaState extends State<EntradaAnimada>
    with SingleTickerProviderStateMixin {
  late final AnimationController _control;
  late final Animation<double> _opacidad;
  late final Animation<Offset> _desplazamiento;

  @override
  void initState() {
    super.initState();
    final total = widget.retardo + widget.duracion;
    final inicio = total.inMicroseconds == 0
        ? 0.0
        : widget.retardo.inMicroseconds / total.inMicroseconds;
    _control = AnimationController(vsync: this, duration: total);
    final curva = CurvedAnimation(
      parent: _control,
      curve: Interval(inicio, 1, curve: Curves.easeOutCubic),
    );
    _opacidad = curva;
    _desplazamiento = Tween(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(curva);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_control.isAnimating || _control.isCompleted) return;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _control.value = 1;
    } else {
      _control.forward();
    }
  }

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacidad,
      child: SlideTransition(position: _desplazamiento, child: widget.child),
    );
  }
}

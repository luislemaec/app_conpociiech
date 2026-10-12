import 'package:flutter/material.dart';
import '../api_tribunal.dart';
import '../widgets_tribunal.dart';

/// Orientación del flujo, sin deducir permisos ni crear estados electorales.
class GuiaEscrutinio extends StatelessWidget {
  const GuiaEscrutinio({
    super.key,
    required this.acta,
    required this.modificado,
  });
  final ActaPresidente acta;
  final bool modificado;
  @override
  Widget build(BuildContext context) => Seccion(
    titulo: 'Flujo del escrutinio',
    children: [
      const Text(
        '1. Apertura → 2. Conteo → 3. Revisión del cuadre → 4. Guardado → 5. Cierre → 6. Fotografía del acta → 7. Revisión del Tribunal',
      ),
      const SizedBox(height: 16),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(acta.cerrada ? Icons.lock_outline : Icons.edit_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              acta.cerrada
                  ? 'La mesa está cerrada. El conteo ya no se puede modificar.'
                  : modificado
                  ? 'Tiene cambios pendientes de guardar en TEC.'
                  : acta.estado == 'PENDIENTE'
                  ? 'Revise la información y registre la apertura cuando TEC lo permita.'
                  : 'Revise el conteo y el cuadre antes de cerrar la mesa.',
            ),
          ),
        ],
      ),
      if (acta.actaFisica case final foto?) ...[
        const SizedBox(height: 12),
        Text(foto.etiqueta),
      ],
    ],
  );
}

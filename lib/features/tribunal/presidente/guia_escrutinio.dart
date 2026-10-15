import 'package:flutter/material.dart';
import '../api_tribunal.dart';
import '../widgets_tribunal.dart';

/// Orientación del flujo, sin deducir permisos ni crear estados electorales. El paso
/// actual es el que informa TEC en `acta.fase`; la App no lo recalcula.
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
        // «›» y no «→»: Montserrat no incluye la flecha.
        '1. Apertura › 2. Conteo › 3. Acta física › 4. Cierre › 5. Validación',
      ),
      if (acta.fase case final fase?) ...[
        const SizedBox(height: 12),
        EtiquetaFase(fase),
      ],
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
                  : 'Guarde el conteo, suba la foto del acta física firmada y luego cierre la mesa.',
            ),
          ),
        ],
      ),
    ],
  );
}

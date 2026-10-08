import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_router.dart';
import '../api_tribunal.dart';
import '../widgets_tribunal.dart';

/// Mesa asignada al Presidente en el proceso activo (por su designación JRV).
class PantallaMiMesa extends StatelessWidget {
  const PantallaMiMesa({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<ApiTribunal>();
    return Scaffold(
      appBar: AppBar(title: const Text('Mi mesa')),
      body: VistaConsulta<MesaPresidente>(
        cargar: api.mesaPresidente,
        construir: (context, mesa) => ContenidoConsulta(
          children: [
            Seccion(
              titulo: mesa.ubicacion.mesa,
              children: [
                Align(alignment: Alignment.centerLeft, child: EtiquetaEstado(mesa.estado)),
                const SizedBox(height: 12),
                Dato('Proceso', mesa.proceso.nombre),
                Dato('Fase vigente', mesa.proceso.faseVigente),
                Dato('Recinto', mesa.ubicacion.recinto),
                Dato('Ubicación', mesa.ubicacion.lugar),
                Dato('Electores', formatoNumero(mesa.electores)),
                if (mesa.fechaApertura != null) Dato('Apertura', formatoFecha(mesa.fechaApertura)),
                if (mesa.fechaCierre != null) Dato('Cierre', formatoFecha(mesa.fechaCierre)),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => context.go(Rutas.padronMesa),
                  icon: const Icon(Icons.people_outline),
                  label: const Text('Ver padrón de la mesa'),
                ),
              ],
            ),
            Seccion(
              titulo: 'Junta Receptora del Voto',
              children: [
                if (mesa.junta.isEmpty) const Text('Aún no hay miembros designados.'),
                for (final m in mesa.junta) Dato(m.cargo ?? 'Miembro', m.nombre),
              ],
            ),
            if (mesa.resultados case final r?)
              Seccion(
                titulo: 'Resultados de la mesa',
                children: [
                  Indicadores({
                    'Sufragantes': formatoNumero(r.sufragantes),
                    'Votos registrados': formatoNumero(r.votosRegistrados),
                    'Votos válidos': formatoNumero(r.votosValidos),
                    'Blancos': formatoNumero(r.votosBlancos),
                    'Nulos': formatoNumero(r.votosNulos),
                  }),
                  const SizedBox(height: 12),
                  for (final c in r.categorias) Dato(c.categoria, formatoNumero(c.votos)),
                ],
              )
            else
              const Seccion(
                titulo: 'Resultados de la mesa',
                children: [Text('Los resultados se muestran cuando la mesa está cerrada.')],
              ),
          ],
        ),
      ),
    );
  }
}

/// Padrón de la mesa del Presidente, con búsqueda local por nombre o iglesia.
class PantallaPadronMesa extends StatefulWidget {
  const PantallaPadronMesa({super.key});

  @override
  State<PantallaPadronMesa> createState() => _PantallaPadronMesaState();
}

class _PantallaPadronMesaState extends State<PantallaPadronMesa> {
  String _filtro = '';

  @override
  Widget build(BuildContext context) {
    final api = context.read<ApiTribunal>();
    return Scaffold(
      appBar: AppBar(title: const Text('Padrón de la mesa')),
      body: VistaConsulta<List<Elector>>(
        cargar: api.padronPresidente,
        construir: (context, electores) {
          final f = _filtro.toLowerCase();
          final visibles = f.isEmpty
              ? electores
              : electores
                  .where((e) => e.nombre.toLowerCase().contains(f) || (e.iglesia?.toLowerCase().contains(f) ?? false))
                  .toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  decoration: const InputDecoration(labelText: 'Buscar por nombre o iglesia', prefixIcon: Icon(Icons.search)),
                  onChanged: (v) => setState(() => _filtro = v.trim()),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('${formatoNumero(visibles.length)} de ${formatoNumero(electores.length)} electores'),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: visibles.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final e = visibles[i];
                    return ListTile(
                      title: Text(e.nombre),
                      subtitle: e.iglesia == null ? null : Text(e.iglesia!),
                      trailing: e.sufrago == true
                          ? const Tooltip(message: 'Sufragó', child: Icon(Icons.how_to_vote))
                          : null,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

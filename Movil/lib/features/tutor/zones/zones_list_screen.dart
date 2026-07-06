import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../app/theme.dart';
import '../../../core/models/zona_segura.dart';
import '../../../core/services/zonas_service.dart';
import 'zone_editor_screen.dart';

class ZonesListScreen extends StatefulWidget {
  const ZonesListScreen({super.key});

  @override
  State<ZonesListScreen> createState() => _ZonesListScreenState();
}

class _ZonesListScreenState extends State<ZonesListScreen> {
  final _zonasService = ZonasService();
  List<ZonaSegura> _zonas = [];
  bool _isLoading = true;
  String _errorMessage = '';
  bool _isSatellite = false;

  @override
  void initState() {
    super.initState();
    _cargarZonas();
  }

  Future<void> _cargarZonas() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final zonas = await _zonasService.getZonas();
      if (mounted) {
        setState(() {
          _zonas = zonas;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _eliminarZona(ZonaSegura zona) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Zona Segura'),
        content: Text('¿Estás seguro de que querés eliminar la zona "${zona.nombre}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.colorDanger),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await _zonasService.eliminarZona(zona.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Zona segura eliminada.'),
            backgroundColor: AppTheme.colorSafe,
          ),
        );
        _cargarZonas();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppTheme.colorDanger,
          ),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(_errorMessage, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        ElevatedButton(onPressed: _cargarZonas, child: const Text('Reintentar')),
                      ],
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Encabezado (Título y Subtítulo con botón satélite)
                      Padding(
                        padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Tus Zonas Seguras',
                                    style: textTheme.headlineLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Define perímetros de seguridad para recibir alertas automáticas',
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: AppTheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(_isSatellite ? Icons.map_outlined : Icons.layers_outlined),
                              onPressed: () {
                                setState(() {
                                  _isSatellite = !_isSatellite;
                                });
                              },
                              tooltip: 'Alternar satélite',
                              color: AppTheme.primaryTeal,
                            ),
                          ],
                        ),
                      ),

                      // Listado de Geocercas
                      Expanded(
                        child: _zonas.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(32.0),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.shield_outlined, size: 80, color: AppTheme.primaryTealLight),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Aún no creaste zonas seguras',
                                        style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                itemCount: _zonas.length,
                                separatorBuilder: (context, index) => const SizedBox(height: 16),
                                itemBuilder: (context, index) {
                                  final zona = _zonas[index];
                                  LatLng center = const LatLng(-17.7846, -63.1806);
                                  if (zona.puntos.isNotEmpty) {
                                    double sumLat = 0;
                                    double sumLng = 0;
                                    for (var p in zona.puntos) {
                                      sumLat += p.latitude;
                                      sumLng += p.longitude;
                                    }
                                    center = LatLng(sumLat / zona.puntos.length, sumLng / zona.puntos.length);
                                  }

                                  return Card(
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: const BorderSide(color: AppTheme.outline, width: 1),
                                    ),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(16),
                                      onLongPress: () => _eliminarZona(zona),
                                      onTap: () async {
                                        final result = await Navigator.push<bool>(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => ZoneEditorScreen(zonaParaEditar: zona),
                                          ),
                                        );
                                        if (result == true) {
                                          _cargarZonas();
                                        }
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            // Encabezado Tarjeta (Nombre + Avatares de Hijos)
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        zona.nombre,
                                                        style: textTheme.titleMedium?.copyWith(
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 16,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        zona.descripcion ?? 'Zona de seguridad familiar',
                                                        style: textTheme.bodyMedium?.copyWith(
                                                          color: AppTheme.onSurfaceVariant,
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                // Avatares de hijos asociados
                                                Row(
                                                  children: zona.hijos.map((hijo) {
                                                    return Container(
                                                      margin: const EdgeInsets.only(left: 4),
                                                      child: CircleAvatar(
                                                        radius: 12,
                                                        backgroundColor: AppTheme.primaryTeal,
                                                        child: Text(
                                                          hijo.nombre.substring(0, 1).toUpperCase(),
                                                          style: const TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 10,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                  }).toList(),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),

                                            // Mini Mapa Preview Estático (Redondeado y adaptado)
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(12),
                                              child: SizedBox(
                                                height: 120,
                                                child: FlutterMap(
                                                  options: MapOptions(
                                                    initialCenter: center,
                                                    initialZoom: 15.0,
                                                    interactionOptions: const InteractionOptions(flags: 0),
                                                  ),
                                                  children: [
                                                    TileLayer(
                                                      urlTemplate: _isSatellite 
                                                          ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                                                          : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                                      userAgentPackageName: 'com.safesteps.safesteps',
                                                      maxZoom: 20,
                                                      maxNativeZoom: _isSatellite ? 17 : 19,
                                                    ),
                                                    PolygonLayer(
                                                      polygons: [
                                                        Polygon(
                                                          points: zona.puntos,
                                                          color: AppTheme.colorSafe.withOpacity(0.2),
                                                          borderColor: AppTheme.colorSafe,
                                                          borderStrokeWidth: 2.0,
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),

                      // Botón Prominente Inferior "+ Crear zona segura"
                      Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final result = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(builder: (context) => const ZoneEditorScreen()),
                            );
                            if (result == true) {
                              _cargarZonas();
                            }
                          },
                          icon: const Icon(Icons.add_circle_outline, size: 20),
                          label: const Text('Crear zona segura'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryTeal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

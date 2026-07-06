import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../app/theme.dart';
import '../../../core/models/hijo.dart';
import '../../../core/models/zona_segura.dart';
import '../../../core/services/hijos_service.dart';
import '../../../core/services/zonas_service.dart';

class ZoneEditorScreen extends StatefulWidget {
  final ZonaSegura? zonaParaEditar;

  const ZoneEditorScreen({super.key, this.zonaParaEditar});

  @override
  State<ZoneEditorScreen> createState() => _ZoneEditorScreenState();
}

class _ZoneEditorScreenState extends State<ZoneEditorScreen> {
  final _zonasService = ZonasService();
  final _hijosService = HijosService();
  final _formKey = GlobalKey<FormState>();
  final _mapController = MapController();

  final _nombreController = TextEditingController();
  final _descripcionController = TextEditingController();

  List<Hijo> _hijosDisponibles = [];
  final List<Hijo> _hijosSeleccionados = [];
  final List<LatLng> _puntosPoligono = [];

  bool _isLoading = true;
  String _errorMessage = '';
  bool _isSatellite = false;

  @override
  void initState() {
    super.initState();
    _cargarHijosYDatos();
  }

  Future<void> _cargarHijosYDatos() async {
    setState(() => _isLoading = true);
    try {
      final hijos = await _hijosService.getMisHijos();
      setState(() {
        _hijosDisponibles = hijos;
        _isLoading = false;

        if (widget.zonaParaEditar != null) {
          final ed = widget.zonaParaEditar!;
          _nombreController.text = ed.nombre;
          _descripcionController.text = ed.descripcion ?? '';
          _puntosPoligono.addAll(ed.puntos);
          
          for (var h in ed.hijos) {
            final match = _hijosDisponibles.firstWhere((hd) => hd.id == h.id);
            _hijosSeleccionados.add(match);
          }

          if (_puntosPoligono.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _mapController.move(_puntosPoligono.first, 14);
            });
          }
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _agregarPunto(TapPosition tapPosition, LatLng point) {
    setState(() {
      _puntosPoligono.add(point);
    });
  }

  void _deshacerUltimoPunto() {
    if (_puntosPoligono.isEmpty) return;
    setState(() {
      _puntosPoligono.removeLast();
    });
  }

  void _limpiarDibujo() {
    setState(() {
      _puntosPoligono.clear();
    });
  }

  Future<void> _guardarZona() async {
    if (!_formKey.currentState!.validate()) return;

    if (_puntosPoligono.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Un polígono de zona segura requiere al menos 3 puntos (vértices).'),
          backgroundColor: AppTheme.colorDanger,
        ),
      );
      return;
    }

    if (_hijosSeleccionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, asociá al menos un hijo a esta zona.'),
          backgroundColor: AppTheme.colorDanger,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final puntosCerrados = List<LatLng>.from(_puntosPoligono);
      if (puntosCerrados.first != puntosCerrados.last) {
        puntosCerrados.add(puntosCerrados.first);
      }

      final zonaData = ZonaSegura(
        id: widget.zonaParaEditar?.id ?? 0,
        nombre: _nombreController.text.trim(),
        descripcion: _descripcionController.text.trim().isEmpty ? null : _descripcionController.text.trim(),
        puntos: puntosCerrados,
        hijos: _hijosSeleccionados,
        fechaCreacion: DateTime.now(),
      );

      if (widget.zonaParaEditar != null) {
        await _zonasService.actualizarZona(widget.zonaParaEditar!.id, zonaData);
      } else {
        await _zonasService.crearZona(zonaData);
      }

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.zonaParaEditar != null ? 'Zona actualizada con éxito.' : 'Zona creada con éxito.'),
          backgroundColor: AppTheme.colorSafe,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      String rawError = e.toString().replaceFirst('Exception: ', '');
      String friendlyMessage = rawError;

      if (rawError.toLowerCase().contains('hijosids') || rawError.toLowerCase().contains('hijos')) {
        friendlyMessage = 'Tenés que seleccionar al menos un hijo para monitorear en esta zona.';
      } else if (rawError.toLowerCase().contains('nombre') || rawError.toLowerCase().contains('name')) {
        friendlyMessage = 'El nombre de la zona es obligatorio.';
      } else if (rawError.toLowerCase().contains('puntos') || rawError.toLowerCase().contains('points')) {
        friendlyMessage = 'La zona debe delimitarse con un polígono válido de al menos 3 puntos.';
      }

      setState(() {
        _errorMessage = friendlyMessage;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.zonaParaEditar != null ? 'Editar Zona Segura' : 'Nueva Zona Segura'),
        actions: [
          // Botones auxiliares de dibujo en la barra superior
          if (_puntosPoligono.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.undo),
              tooltip: 'Deshacer',
              onPressed: _deshacerUltimoPunto,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Limpiar',
              color: AppTheme.colorDanger,
              onPressed: _limpiarDibujo,
            ),
          ]
        ],
      ),
      body: _isLoading && _hijosDisponibles.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: Column(
                children: [
                  // 1. MITAD SUPERIOR: El Mapa de Dibujo (40% de altura)
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.35,
                    child: Stack(
                      children: [
                        FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: const LatLng(-17.7846, -63.1806),
                            initialZoom: 14.5,
                            onTap: _agregarPunto,
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
                            if (_puntosPoligono.length >= 3)
                              PolygonLayer(
                                polygons: [
                                  Polygon(
                                    points: _puntosPoligono,
                                    color: AppTheme.colorSafe.withOpacity(0.2),
                                    borderColor: AppTheme.colorSafe,
                                    borderStrokeWidth: 3.0,
                                  ),
                                ],
                              ),
                            if (_puntosPoligono.isNotEmpty)
                              PolylineLayer(
                                polylines: [
                                  Polyline(
                                    points: _puntosPoligono,
                                    color: AppTheme.primaryTeal,
                                    strokeWidth: 2.0,
                                  ),
                                ],
                              ),
                            MarkerLayer(
                              markers: _puntosPoligono.asMap().entries.map((entry) {
                                final idx = entry.key;
                                final point = entry.value;
                                return Marker(
                                  point: point,
                                  width: 24,
                                  height: 24,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryTeal,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '${idx + 1}',
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
                        // Botón alternar satélite
                        Positioned(
                          top: 12,
                          right: 16,
                          child: FloatingActionButton(
                            heroTag: 'toggle_satellite_editor',
                            mini: true,
                            backgroundColor: Colors.white,
                            foregroundColor: AppTheme.primaryTeal,
                            onPressed: () {
                              setState(() {
                                _isSatellite = !_isSatellite;
                              });
                            },
                            child: Icon(_isSatellite ? Icons.map_outlined : Icons.layers_outlined),
                          ),
                        ),
                        // Tooltip flotante instructivo (Mockup 2)
                        Positioned(
                          bottom: 12,
                          left: 16,
                          right: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: const [
                                BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 4,
                                  backgroundColor: Colors.green,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Toca el mapa para definir los puntos del perímetro',
                                  style: TextStyle(
                                    color: AppTheme.onSurface,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 2. MITAD INFERIOR: Formulario en Tarjeta Scrollable (60% restante)
                  Expanded(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                        boxShadow: [
                          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -3))
                        ],
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_errorMessage.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: AppTheme.colorDanger.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppTheme.colorDanger.withOpacity(0.3)),
                                ),
                                child: Text(
                                  _errorMessage,
                                  style: textTheme.bodyMedium?.copyWith(color: AppTheme.colorDanger),
                                ),
                              ),
                            ],

                            // Campo Nombre
                            Text(
                              'Nombre de la zona (requerido)',
                              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _nombreController,
                              decoration: const InputDecoration(
                                hintText: 'Ej. Parque Central',
                                prefixIcon: Icon(Icons.shield_outlined),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Por favor ingresá el nombre de la zona.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Campo Descripción
                            Text(
                              'Descripción (opcional)',
                              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _descripcionController,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                hintText: 'Añade detalles sobre esta zona...',
                                prefixIcon: Icon(Icons.notes),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Selector de integrantes / Hijos
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Asociar integrantes (mínimo uno)',
                                  style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'Seleccionados: ${_hijosSeleccionados.length}',
                                  style: textTheme.labelLarge?.copyWith(
                                    color: AppTheme.primaryTeal,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            _hijosDisponibles.isEmpty
                                ? const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8.0),
                                    child: Text('Primero tenés que registrar hijos en la sección Familia.'),
                                  )
                                : ListView.separated(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: _hijosDisponibles.length,
                                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                                    itemBuilder: (context, index) {
                                      final hijo = _hijosDisponibles[index];
                                      final isSelected = _hijosSeleccionados.any((h) => h.id == hijo.id);

                                      return Card(
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          side: BorderSide(
                                            color: isSelected ? AppTheme.primaryTeal : AppTheme.outline,
                                            width: isSelected ? 1.5 : 1,
                                          ),
                                        ),
                                        child: CheckboxListTile(
                                          controlAffinity: ListTileControlAffinity.trailing,
                                          title: Text(
                                            '${hijo.nombre} ${hijo.apellido ?? ''}',
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          subtitle: const Text('Hijo • Activo'),
                                          secondary: CircleAvatar(
                                            backgroundColor: AppTheme.primaryTealSurface,
                                            child: const Icon(Icons.person, color: AppTheme.primaryTeal),
                                          ),
                                          value: isSelected,
                                          activeColor: AppTheme.primaryTeal,
                                          onChanged: (bool? checked) {
                                            setState(() {
                                              if (checked == true) {
                                                _hijosSeleccionados.add(hijo);
                                              } else {
                                                _hijosSeleccionados.removeWhere((h) => h.id == hijo.id);
                                              }
                                            });
                                          },
                                        ),
                                      );
                                    },
                                  ),
                            const SizedBox(height: 24),

                            // Botón Guardar
                            ElevatedButton.icon(
                              onPressed: _isLoading ? null : _guardarZona,
                              icon: const Icon(Icons.save_outlined, size: 20),
                              label: const Text('Guardar zona segura'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryTeal,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                            ),
                          ],
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

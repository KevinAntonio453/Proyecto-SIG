import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../app/theme.dart';
import '../../core/models/hijo.dart';
import '../../core/models/zona_segura.dart';

import '../../core/services/hijos_service.dart';
import '../../core/services/zonas_service.dart';
import '../../core/services/registros_service.dart';
import '../../core/services/socket_service.dart';

import 'notification_bell.dart';

class TutorMapScreen extends StatefulWidget {
  const TutorMapScreen({super.key});

  @override
  State<TutorMapScreen> createState() => _TutorMapScreenState();
}

class _TutorMapScreenState extends State<TutorMapScreen> {
  final _hijosService = HijosService();
  final _zonasService = ZonasService();
  final _registrosService = RegistrosService();
  final _socketService = SocketService();
  final _mapController = MapController();

  List<Hijo> _hijos = [];
  List<ZonaSegura> _zonas = [];
  List<LatLng> _historialRuta = []; // Coordenadas de trayectoria del hijo seleccionado
  
  Hijo? _hijoSeleccionado;
  bool _isLoading = true;
  bool _mostrarRuta = false;
  bool _isSatellite = false;


  @override
  void initState() {
    super.initState();
    _cargarDatosIniciales();
    _configurarWebSockets();
  }

  Future<void> _cargarDatosIniciales() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final hijos = await _hijosService.getMisHijos();
      final zonas = await _zonasService.getZonas();
      
      if (mounted) {
        setState(() {
          _hijos = hijos;
          _zonas = zonas;
          _isLoading = false;
          
          if (_hijos.isNotEmpty) {
            _seleccionarHijo(_hijos.first);
          }
        });
        _suscribirseAHijos(); // Suscribirse una vez que se cargan los hijos
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _configurarWebSockets() {
    // Conectar WebSocket si no está conectado
    _socketService.connect().then((_) {
      _suscribirseAHijos(); // Suscribirse una vez conectado
    });

    // Escuchar actualizaciones de ubicación en tiempo real
    _socketService.registerLocationCallback(_onLocationUpdated);
    // Escuchar cambios de estado (online/offline)
    _socketService.registerStatusCallback(_onStatusChanged);
  }

  void _suscribirseAHijos() {
    if (_socketService.isConnected) {
      for (var hijo in _hijos) {
        _socketService.suscribirseAHijo(hijo.id);
      }
    }
  }

  void _onLocationUpdated(Map<String, dynamic> data) {
    if (!mounted) return;
    
    final childId = int.tryParse(data['childId'].toString()) ?? 0;
    final double lat = (data['lat'] as num).toDouble();
    final double lng = (data['lng'] as num).toDouble();


    setState(() {
      // Actualizar ubicación del hijo en la lista local
      final index = _hijos.indexWhere((h) => h.id == childId);
      if (index != -1) {
        final hijoActualizado = Hijo(
          id: _hijos[index].id,
          nombre: _hijos[index].nombre,
          apellido: _hijos[index].apellido,
          email: _hijos[index].email,
          tipo: _hijos[index].tipo,
          fcmToken: _hijos[index].fcmToken,
          telefono: _hijos[index].telefono,
          latitud: lat,
          longitud: lng,
          ultimaConexion: DateTime.now(),
          codigoVinculacion: _hijos[index].codigoVinculacion,
          vinculado: _hijos[index].vinculado,
          estadoZona: data['estadoZona'] as String? ?? _hijos[index].estadoZona,
          zonaActualId: data['zonaActualId'] as int? ?? _hijos[index].zonaActualId,
        );
        _hijos[index] = hijoActualizado;

        // Si es el hijo seleccionado, mover mapa y agregar al recorrido en vivo
        if (_hijoSeleccionado?.id == childId) {
          _hijoSeleccionado = hijoActualizado;
          if (_mostrarRuta) {
            _historialRuta.add(LatLng(lat, lng));
          }
          _mapController.move(LatLng(lat, lng), _mapController.camera.zoom);
        }
      }
    });
  }

  void _onStatusChanged(Map<String, dynamic> data) {
    if (!mounted) return;
    final childId = int.tryParse(data['childId'].toString()) ?? 0;
    final bool online = data['online'] as bool? ?? false;

    setState(() {
      final index = _hijos.indexWhere((h) => h.id == childId);
      if (index != -1) {
        // Para simplificar la visualización de estado en tiempo real, guardamos la conexión
        // en el campo ultimaConexion (si está offline ponemos null o mantenemos el valor)
        final hijoActualizado = Hijo(
          id: _hijos[index].id,
          nombre: _hijos[index].nombre,
          apellido: _hijos[index].apellido,
          email: _hijos[index].email,
          tipo: _hijos[index].tipo,
          fcmToken: _hijos[index].fcmToken,
          telefono: _hijos[index].telefono,
          latitud: _hijos[index].latitud,
          longitud: _hijos[index].longitud,
          ultimaConexion: online ? DateTime.now() : null, // null indica offline
          codigoVinculacion: _hijos[index].codigoVinculacion,
          vinculado: _hijos[index].vinculado,
          estadoZona: _hijos[index].estadoZona,
          zonaActualId: _hijos[index].zonaActualId,
        );
        _hijos[index] = hijoActualizado;
        if (_hijoSeleccionado?.id == childId) {
          _hijoSeleccionado = hijoActualizado;
        }
      }
    });
  }

  Future<void> _seleccionarHijo(Hijo hijo) async {
    setState(() {
      _hijoSeleccionado = hijo;
      _historialRuta.clear();
      _mostrarRuta = false;
    });

    if (hijo.latitud != null && hijo.longitud != null) {
      _mapController.move(LatLng(hijo.latitud!, hijo.longitud!), 16.5);
    }
  }

  // Cargar historial de recorrido desde la base de datos vía HTTP
  Future<void> _cargarHistorialRuta() async {
    if (_hijoSeleccionado == null) return;
    
    setState(() => _isLoading = true);
    try {
      final hoy = DateTime.now();
      final inicio = hoy.subtract(const Duration(hours: 12)); // Últimas 12 horas
      final registros = await _registrosService.getHistorial(_hijoSeleccionado!.id, inicio: inicio, fin: hoy);
      
      setState(() {
        _historialRuta = registros.map((r) => LatLng(r.latitud, r.longitud)).toList();
        _mostrarRuta = true;
        _isLoading = false;
      });

      if (_historialRuta.isNotEmpty) {
        // Ajustar mapa para englobar la trayectoria
        _mapController.move(_historialRuta.first, 15);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cargando historial: ${e.toString()}'),
            backgroundColor: AppTheme.colorDanger,
          ),
        );
      }
      setState(() {
        _mostrarRuta = false;
        _isLoading = false;
      });
    }
  }

  // Determinar color del marcador según el estado del hijo
  Color _getMarcadorColor(Hijo hijo) {
    if (hijo.ultimaConexion == null) return AppTheme.colorOffline; // Desconectado
    if (hijo.estadoZona == 'DENTRO') return AppTheme.colorSafe;
    return AppTheme.colorWarning; // FUERA o alerta
  }

  @override
  void dispose() {
    _socketService.unregisterLocationCallback(_onLocationUpdated);
    _socketService.unregisterStatusCallback(_onStatusChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    // Crear marcadores para flutter_map
    final markers = _hijos
        .where((h) => h.latitud != null && h.longitud != null)
        .map((hijo) {
          final isSelected = _hijoSeleccionado?.id == hijo.id;
          final color = _getMarcadorColor(hijo);

          return Marker(
            point: LatLng(hijo.latitud!, hijo.longitud!),
            width: isSelected ? 60 : 45,
            height: isSelected ? 60 : 45,
            child: GestureDetector(
              onTap: () => _seleccionarHijo(hijo),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Anillo exterior pulsante/animado para el seleccionado
                  if (isSelected)
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                    ),
                  // Marcador circular principal
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3))
                      ],
                    ),
                    child: const Icon(Icons.person, color: Colors.white, size: 20),
                  ),
                ],
              ),
            ),
          );
        }).toList();

    // Crear polígonos para las geocercas
    final polygons = _zonas.map((zona) {
      final tieneHijoSeleccionado = zona.hijos.any((h) => h.id == _hijoSeleccionado?.id);
      return Polygon(
        points: zona.puntos,
        color: AppTheme.colorSafe.withOpacity(0.2),
        borderColor: AppTheme.colorSafe.withOpacity(0.8),
        borderStrokeWidth: tieneHijoSeleccionado ? 3.0 : 1.5,
      );
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa de Monitoreo'),
        actions: [
          const NotificationBell(),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarDatosIniciales,
          )
        ],
      ),
      body: _isLoading && _hijos.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // 1. Capa de Mapa con flutter_map
                 FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _hijoSeleccionado?.latitud != null 
                        ? LatLng(_hijoSeleccionado!.latitud!, _hijoSeleccionado!.longitud!)
                        : const LatLng(-17.7846, -63.1806), // Santa Cruz, Bolivia por defecto
                    initialZoom: 14.0,
                    maxZoom: _isSatellite ? 17.0 : 19.0,
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
                    // Capa de geocercas
                    PolygonLayer(polygons: polygons),
                    // Capa de línea de trayectoria
                    if (_mostrarRuta && _historialRuta.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _historialRuta,
                            color: AppTheme.primaryTealLight,
                            strokeWidth: 4.0,
                          ),
                        ],
                      ),
                    // Capa de marcadores
                    MarkerLayer(markers: markers),
                  ],
                ),

                // Botón alternar satélite
                Positioned(
                  bottom: 180,
                  right: 16,
                  child: FloatingActionButton(
                    heroTag: 'toggle_satellite_map_screen',
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

                // Botón centrar en ubicación del hijo
                Positioned(
                  bottom: 230,
                  right: 16,
                  child: FloatingActionButton(
                    heroTag: 'center_on_child_map_screen',
                    mini: true,
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.primaryTeal,
                    onPressed: () {
                      if (_hijoSeleccionado != null && _hijoSeleccionado!.latitud != null && _hijoSeleccionado!.longitud != null) {
                        _mapController.move(LatLng(_hijoSeleccionado!.latitud!, _hijoSeleccionado!.longitud!), 17.0);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('No hay ubicación disponible para centrar.'),
                            backgroundColor: AppTheme.secondaryCoral,
                          ),
                        );
                      }
                    },
                    child: const Icon(Icons.my_location),
                  ),
                ),

                // Botón centrar en zona segura
                if (_zonas.isNotEmpty)
                  Positioned(
                    bottom: 280,
                    right: 16,
                    child: Container(
                      height: 40,
                      width: 40,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
                        ],
                      ),
                      child: PopupMenuButton<ZonaSegura>(
                        icon: const Icon(Icons.shield_outlined, color: AppTheme.primaryTeal, size: 20),
                        tooltip: 'Centrar en Zona Segura',
                        onSelected: (zona) {
                          if (zona.puntos.isNotEmpty) {
                            double sumLat = 0;
                            double sumLng = 0;
                            for (var p in zona.puntos) {
                              sumLat += p.latitude;
                              sumLng += p.longitude;
                            }
                            final center = LatLng(sumLat / zona.puntos.length, sumLng / zona.puntos.length);
                            _mapController.move(center, 15.5);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Enfocando zona: ${zona.nombre}'),
                                backgroundColor: AppTheme.primaryTeal,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        itemBuilder: (context) {
                          return _zonas.map((zona) {
                            return PopupMenuItem<ZonaSegura>(
                              value: zona,
                              child: Text(zona.nombre),
                            );
                          }).toList();
                        },
                      ),
                    ),
                  ),

                // 2. Chips de Selección rápida de Hijos (Superior)
                if (_hijos.isNotEmpty)
                  Positioned(
                    top: 16,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 50,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        itemCount: _hijos.length,
                        separatorBuilder: (context, index) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final hijo = _hijos[index];
                          final isSelected = _hijoSeleccionado?.id == hijo.id;
                          final statusColor = _getMarcadorColor(hijo);

                          return RawChip(
                            label: Text(hijo.nombre),
                            selected: isSelected,
                            onSelected: (_) => _seleccionarHijo(hijo),
                            avatar: CircleAvatar(
                              backgroundColor: statusColor,
                              radius: 6,
                            ),
                            selectedColor: AppTheme.primaryTealSurface,
                            checkmarkColor: AppTheme.primaryTeal,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            side: BorderSide(
                              color: isSelected ? AppTheme.primaryTeal : AppTheme.outline,
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                // 3. Bottom Sheet de información del hijo seleccionado
                if (_hijoSeleccionado != null)
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Card(
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: AppTheme.outline, width: 1.5),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: _getMarcadorColor(_hijoSeleccionado!),
                                  radius: 20,
                                  child: const Icon(Icons.person, color: Colors.white),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${_hijoSeleccionado!.nombre} ${_hijoSeleccionado!.apellido ?? ''}',
                                        style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _hijoSeleccionado!.ultimaConexion == null
                                            ? 'Offline (Desconectado)'
                                            : 'Estado: ${_hijoSeleccionado!.estadoZona}',
                                        style: textTheme.bodyMedium?.copyWith(
                                          color: _getMarcadorColor(_hijoSeleccionado!),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Botón para solicitar ubicación instantánea
                                OutlinedButton.icon(
                                  onPressed: () {
                                    _socketService.solicitarUbicacionHijo(_hijoSeleccionado!.id);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Solicitando ubicación en tiempo real...'),
                                        backgroundColor: AppTheme.primaryTeal,
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.my_location, size: 18),
                                  label: const Text('Localizar'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  ),
                                ),
                                // Botón para ver trayectoria histórica
                                ElevatedButton.icon(
                                  onPressed: _mostrarRuta ? () => setState(() => _mostrarRuta = false) : _cargarHistorialRuta,
                                  icon: Icon(_mostrarRuta ? Icons.visibility_off : Icons.history, size: 18),
                                  label: Text(_mostrarRuta ? 'Ocultar Ruta' : 'Ver Ruta'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _mostrarRuta ? AppTheme.secondaryCoral : AppTheme.primaryTeal,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

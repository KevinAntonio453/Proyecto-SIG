import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../app/theme.dart';
import '../../core/models/zona_segura.dart';
import '../../core/services/zonas_service.dart';

class HijoLocationScreen extends StatefulWidget {
  const HijoLocationScreen({super.key});

  @override
  State<HijoLocationScreen> createState() => _HijoLocationScreenState();
}

class _HijoLocationScreenState extends State<HijoLocationScreen> {
  final _zonasService = ZonasService();
  final _mapController = MapController();

  LatLng? _currentPosition;
  List<ZonaSegura> _zonas = [];
  bool _isLoading = true;
  String _gpsStatus = 'Obteniendo ubicación...';
  bool _isSatellite = false;
  StreamSubscription? _serviceSubscription;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  Future<void> _inicializar() async {
    await _cargarZonas();
    
    // Suscribirse a las actualizaciones del servicio en segundo plano
    final service = FlutterBackgroundService();
    
    _serviceSubscription = service.on('update').listen((event) {
      if (mounted && event != null) {
        final lat = event['latitude'] as double?;
        final lng = event['longitude'] as double?;
        if (lat != null && lng != null) {
          setState(() {
            _currentPosition = LatLng(lat, lng);
            _gpsStatus = 'Ubicación en tiempo real activa';
          });
        }
      }
    });

    service.invoke('queryStatus');
    
    // Obtener una coordenada inicial rápida
    await _obtenerUbicacionActual();
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _obtenerUbicacionActual() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _gpsStatus = 'Servicios de ubicación desactivados.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _gpsStatus = 'Permiso de ubicación denegado.');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _gpsStatus = 'Permisos de ubicación denegados permanentemente.');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _gpsStatus = 'Ubicación obtenida con éxito';
      });
    } catch (e) {
      setState(() => _gpsStatus = 'Error al obtener ubicación: $e');
    }
  }

  Future<void> _cargarZonas() async {
    try {
      final zonas = await _zonasService.getZonas();
      setState(() => _zonas = zonas);
    } catch (e) {
      debugPrint('Error al cargar zonas: $e');
    }
  }

  @override
  void dispose() {
    _serviceSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final polygons = _zonas.map<Polygon<Object>>((zona) {
      return Polygon(
        points: zona.puntos,
        color: AppTheme.primaryTeal.withOpacity(0.15),
        borderStrokeWidth: 2,
        borderColor: AppTheme.primaryTeal,
      );
    }).toList();

    final markers = <Marker>[];
    if (_currentPosition != null) {
      markers.add(
        Marker(
          point: _currentPosition!,
          width: 50,
          height: 50,
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.primaryTeal.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                color: AppTheme.primaryTeal,
                shape: BoxShape.circle,
                border: Border.fromBorderSide(
                  BorderSide(color: Colors.white, width: 3),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Mi Ubicación')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentPosition ?? const LatLng(-17.7846, -63.1806),
                    initialZoom: 15.0,
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
                    PolygonLayer(polygons: polygons),
                    MarkerLayer(markers: markers),
                  ],
                ),
                // Botón alternar satélite
                Positioned(
                  bottom: 110,
                  right: 16,
                  child: FloatingActionButton(
                    heroTag: 'toggle_satellite_hijo',
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
                // Estado de GPS
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Icon(
                            _currentPosition != null ? Icons.gps_fixed : Icons.gps_off,
                            color: _currentPosition != null ? AppTheme.colorSafe : AppTheme.colorOffline,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _gpsStatus,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                if (_currentPosition != null)
                                  Text(
                                    '${_currentPosition!.latitude.toStringAsFixed(5)}, ${_currentPosition!.longitude.toStringAsFixed(5)}',
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.my_location, color: AppTheme.primaryTeal),
                            onPressed: () async {
                              setState(() => _isLoading = true);
                              await _obtenerUbicacionActual();
                              setState(() => _isLoading = false);
                            },
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

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
import '../../core/services/auth_service.dart';
import 'notification_bell.dart';

class TutorHomeScreen extends StatefulWidget {
  const TutorHomeScreen({super.key});

  @override
  State<TutorHomeScreen> createState() => _TutorHomeScreenState();
}

class _TutorHomeScreenState extends State<TutorHomeScreen> {
  final _hijosService = HijosService();
  final _zonasService = ZonasService();
  final _registrosService = RegistrosService();
  final _socketService = SocketService();
  final _authService = AuthService();
  final _mapController = MapController();

  List<Hijo> _hijos = [];
  List<ZonaSegura> _zonas = [];
  List<LatLng> _historialRuta = [];
  
  Hijo? _hijoSeleccionado;
  String _nombreTutor = 'Tutor';
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
      final user = await _authService.getCurrentUser();
      
      if (mounted) {
        setState(() {
          _hijos = hijos;
          _zonas = zonas;
          _nombreTutor = user?.nombre ?? 'Tutor';
          _isLoading = false;
          
          if (_hijos.isNotEmpty) {
            _seleccionarHijo(_hijos.first);
          }
        });
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
    _socketService.connect().then((_) {
      for (var hijo in _hijos) {
        _socketService.suscribirseAHijo(hijo.id);
      }
    });

    _socketService.registerLocationCallback(_onLocationUpdated);
    _socketService.registerStatusCallback(_onStatusChanged);
  }

  void _onLocationUpdated(Map<String, dynamic> data) {
    if (!mounted) return;
    
    final childIdStr = data['childId'] as String;
    final childId = int.parse(childIdStr);
    final double lat = (data['lat'] as num).toDouble();
    final double lng = (data['lng'] as num).toDouble();

    setState(() {
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
    final childId = int.parse(data['childId'] as String);
    final bool online = data['online'] as bool? ?? false;

    setState(() {
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
          latitud: _hijos[index].latitud,
          longitud: _hijos[index].longitud,
          ultimaConexion: online ? DateTime.now() : null,
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
      _mapController.move(LatLng(hijo.latitud!, hijo.longitud!), 15);
    }
  }

  Future<void> _cargarHistorialRuta() async {
    if (_hijoSeleccionado == null) return;
    
    setState(() => _isLoading = true);
    try {
      final hoy = DateTime.now();
      final inicio = hoy.subtract(const Duration(hours: 12));
      final registros = await _registrosService.getHistorial(_hijoSeleccionado!.id, inicio: inicio, fin: hoy);
      
      setState(() {
        _historialRuta = registros.map((r) => LatLng(r.latitud, r.longitud)).toList();
        _mostrarRuta = true;
        _isLoading = false;
      });

      if (_historialRuta.isNotEmpty) {
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

  Color _getMarcadorColor(Hijo hijo) {
    if (hijo.ultimaConexion == null) return AppTheme.colorOffline;
    if (hijo.estadoZona == 'DENTRO') return AppTheme.colorSafe;
    return AppTheme.colorWarning;
  }

  // Banner superior dinámico con el estado familiar
  Widget _buildSafetyBanner() {
    final hijosFuera = _hijos.where((h) => h.ultimaConexion != null && h.estadoZona == 'FUERA').toList();
    
    final bool todosADisalvo = hijosFuera.isEmpty;
    final Color bannerColor = todosADisalvo ? AppTheme.colorSafe : AppTheme.colorWarning;
    final IconData icon = todosADisalvo ? Icons.check_circle : Icons.warning;
    final String text = todosADisalvo
        ? 'Todos tus hijos están en zona segura'
        : '${hijosFuera.map((h) => h.nombre).join(", ")} está fuera de zona segura';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: bannerColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: bannerColor.withOpacity(0.4), width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: bannerColor, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: bannerColor,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
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

    // Marcadores para el mapa
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
                  if (isSelected)
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                    ),
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

    // Polígonos de zonas
    final polygons = _zonas.map((zona) {
      return Polygon(
        points: zona.puntos,
        color: AppTheme.colorSafe.withOpacity(0.2),
        borderColor: AppTheme.colorSafe.withOpacity(0.8),
        borderStrokeWidth: 2.0,
      );
    }).toList();

    return Scaffold(
      body: _isLoading && _hijos.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // 1. Capa de Mapa
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _hijoSeleccionado?.latitud != null 
                        ? LatLng(_hijoSeleccionado!.latitud!, _hijoSeleccionado!.longitud!)
                        : const LatLng(-17.7846, -63.1806),
                    initialZoom: 14.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: _isSatellite 
                          ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                          : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.safesteps.safesteps',
                      maxZoom: 20,
                      maxNativeZoom: 18,
                    ),
                    PolygonLayer(polygons: polygons),
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
                    MarkerLayer(markers: markers),
                  ],
                ),

                // Botón alternar satélite
                Positioned(
                  bottom: 180,
                  right: 16,
                  child: FloatingActionButton(
                    heroTag: 'toggle_satellite_home',
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

                // 2. Cabecera flotante superior (Hola Ana + Campana)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 10,
                  left: 16,
                  right: 16,
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Badge de Bienvenida Tutor
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: const [
                                BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))
                              ],
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: AppTheme.primaryTealSurface,
                                  child: const Icon(Icons.person, size: 16, color: AppTheme.primaryTeal),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Hola, $_nombreTutor',
                                  style: textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryTeal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Campana de notificaciones flotante
                          Container(
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))
                              ],
                            ),
                            child: const NotificationBell(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Banner dinámico de estado familiar
                      _buildSafetyBanner(),
                      const SizedBox(height: 10),

                      // 3. DISEÑO 2: Selector flotante Dropdown Pill del hijo
                      if (_hijos.isNotEmpty && _hijoSeleccionado != null)
                        PopupMenuButton<Hijo>(
                          onSelected: _seleccionarHijo,
                          offset: const Offset(0, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          itemBuilder: (context) {
                            return _hijos.map((hijo) {
                              return PopupMenuItem<Hijo>(
                                value: hijo,
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 12,
                                      backgroundColor: _getMarcadorColor(hijo),
                                      child: const Icon(Icons.person, size: 14, color: Colors.white),
                                    ),
                                    const SizedBox(width: 10),
                                    Text('${hijo.nombre} ${hijo.apellido ?? ''}'),
                                  ],
                                ),
                              );
                            }).toList();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: AppTheme.outline, width: 1.5),
                              boxShadow: const [
                                BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: _getMarcadorColor(_hijoSeleccionado!),
                                  child: const Icon(Icons.person, size: 16, color: Colors.white),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  '${_hijoSeleccionado!.nombre} ${_hijoSeleccionado!.apellido ?? ''}',
                                  style: textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.keyboard_arrow_down, color: AppTheme.onSurfaceVariant),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // 4. Detalle inferior del hijo seleccionado
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

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../app/theme.dart';
import '../../core/models/user.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/hijos_service.dart';
import '../../core/services/socket_service.dart';
import '../../core/services/registros_service.dart';
import '../../core/models/registro.dart';
import '../auth/welcome_screen.dart';

class HijoStatusScreen extends StatefulWidget {
  const HijoStatusScreen({super.key});

  @override
  State<HijoStatusScreen> createState() => _HijoStatusScreenState();
}

class _HijoStatusScreenState extends State<HijoStatusScreen> {
  final _authService = AuthService();
  final _hijosService = HijosService();
  final _socketService = SocketService();
  final _registrosService = RegistrosService();

  User? _currentUser;
  bool _isConnected = false;
  String _gpsStatus = 'Inicializando GPS...';
  Position? _currentPosition;
  StreamSubscription<Position>? _positionStreamSubscription;

  // Estado del botón SOS
  double _sosProgress = 0.0;
  Timer? _sosTimer;
  bool _sosActive = false;

  @override
  void initState() {
    super.initState();
    _inicializarServicios();
  }

  Future<void> _inicializarServicios() async {
    // 1. Obtener datos del usuario logueado
    final user = await _authService.getCurrentUser();
    if (mounted) {
      setState(() {
        _currentUser = user;
      });
    }

    // 2. Conectar WebSocket y configurar escuchas
    await _socketService.connect();
    if (mounted) {
      setState(() {
        _isConnected = _socketService.isConnected;
      });
    }

    // Escuchar cambios de estado en el socket
    _socketService.socket?.on('connect', (_) {
      if (mounted) setState(() => _isConnected = true);
      _socketService.marcarOnline();
    });
    
    _socketService.socket?.on('disconnect', (_) {
      if (mounted) setState(() => _isConnected = false);
    });

    _socketService.marcarOnline();

    // Escuchar cuando el tutor solicita ubicación manual
    _socketService.registerLocationRequestCallback((data) async {
      print('Tutor solicitó ubicación manual.');
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 5),
        );
        _socketService.enviarUbicacion(
          position.latitude,
          position.longitude,
          status: 'requested',
        );
      } catch (e) {
        debugPrint('Error obteniendo ubicación en caliente: $e');
        if (_currentPosition != null) {
          _socketService.enviarUbicacion(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            status: 'requested',
          );
        }
      }
    });

    // 3. Inicializar GPS
    _iniciarGps();
  }

  Future<void> _iniciarGps() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Verificar si los servicios de ubicación están activos
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) setState(() => _gpsStatus = 'Servicios de ubicación inactivos.');
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) setState(() => _gpsStatus = 'Permisos de ubicación denegados.');
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      if (mounted) setState(() => _gpsStatus = 'Permisos de ubicación denegados permanentemente.');
      return;
    }

    if (mounted) setState(() => _gpsStatus = 'GPS Activo. Transmitiendo...');

    // Configurar stream de ubicación en tiempo real
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // Notificar cada 5 metros
    );

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      if (!mounted) return;
      
      setState(() {
        _currentPosition = position;
        _gpsStatus = 'Ubicación: ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
      });

      // 1. Enviar ubicación en tiempo real por WebSocket
      _socketService.enviarUbicacion(position.latitude, position.longitude);

      // 2. Guardar registro en base de datos vía HTTP (historial de trayectorias)
      if (_currentUser != null) {
        _registrosService.registrarUbicacion(
          Registro(
            hora: DateTime.now(),
            latitud: position.latitude,
            longitud: position.longitude,
            hijoId: _currentUser!.id,
            fueOffline: false,
          ),
        ).then((_) => null).catchError((err) {
          print('Error persistiendo ubicación: $err');
          return null;
        });
      }
    });
  }

  // --- CONTROL DEL BOTÓN SOS ---

  void _iniciarSosPress() {
    if (_sosActive) return;

    _sosTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      setState(() {
        _sosProgress += 0.0167; // Aumentar hasta llegar a 1.0 en ~3 segundos (50ms * 60 = 3000ms)
        if (_sosProgress >= 1.0) {
          _sosProgress = 1.0;
          _triggerSos();
          _cancelarSosPress();
        }
      });
    });
  }

  void _cancelarSosPress() {
    _sosTimer?.cancel();
    _sosTimer = null;
    if (_sosProgress < 1.0) {
      setState(() {
        _sosProgress = 0.0;
      });
    }
  }

  Future<void> _triggerSos() async {
    if (_currentUser == null || _currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se puede enviar SOS. Esperando señal GPS.'),
          backgroundColor: AppTheme.colorDanger,
        ),
      );
      return;
    }

    setState(() {
      _sosActive = true;
    });

    try {
      // 1. Emitir alerta de pánico por WebSocket (inmediato para tutores en sala)
      _socketService.emitirAlertaPanic(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );

      // 2. Enviar alerta por HTTP (para registro y notificaciones FCM)
      await _hijosService.enviarSOS(_currentUser!.id);

      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.emergency, color: AppTheme.colorDanger, size: 48),
          title: const Text('🚨 ALERTA SOS ENVIADA'),
          content: const Text(
            'Se ha notificado de inmediato a todos tus tutores con tu ubicación actual y se activó una alerta de pánico.',
            textAlign: TextAlign.center,
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() => _sosActive = false);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.colorDanger),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() {
        _sosActive = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error enviando SOS: ${e.toString()}'),
          backgroundColor: AppTheme.colorDanger,
        ),
      );
    }
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _socketService.marcarOffline();
    _socketService.disconnect();
    _sosTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentUser?.nombre ?? 'Panel de Hijo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              _socketService.marcarOffline();
              await _authService.logout();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const WelcomeScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Banner de estado de conexión
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: _isConnected 
                      ? AppTheme.colorSafe.withOpacity(0.1)
                      : AppTheme.colorDanger.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isConnected 
                        ? AppTheme.colorSafe.withOpacity(0.3)
                        : AppTheme.colorDanger.withOpacity(0.3)
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _isConnected ? AppTheme.colorSafe : AppTheme.colorDanger,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _isConnected ? 'Conectado al servidor' : 'Sin conexión con el servidor',
                      style: textTheme.labelLarge?.copyWith(
                        color: _isConnected ? AppTheme.colorSafe : AppTheme.colorDanger,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Tarjeta de estado de GPS
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.gps_fixed,
                        color: _currentPosition != null ? AppTheme.primaryTeal : AppTheme.colorOffline,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Estado de Ubicación',
                              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _gpsStatus,
                              style: textTheme.bodyMedium,
                            ),
                          ],
                        ),
                          ),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // Área del Botón SOS
              Center(
                child: Column(
                  children: [
                    Text(
                      _sosActive ? 'ENVIANDO ALERTA...' : 'MANTENÉ PRESIONADO PARA SOS',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.colorDanger,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Mantené presionado por 3 segundos en caso de peligro.'),
                    const SizedBox(height: 32),
                    
                    // Botón Circular SOS
                    GestureDetector(
                      onTapDown: (_) => _iniciarSosPress(),
                      onTapUp: (_) => _cancelarSosPress(),
                      onTapCancel: () => _cancelarSosPress(),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Anillo de progreso exterior
                          SizedBox(
                            width: 170,
                            height: 170,
                            child: CircularProgressIndicator(
                              value: _sosProgress,
                              strokeWidth: 8,
                              backgroundColor: AppTheme.outline,
                              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.colorDanger),
                            ),
                          ),
                          // Botón rojo interior
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 100),
                            width: _sosProgress > 0 ? 140 : 150,
                            height: _sosProgress > 0 ? 140 : 150,
                            decoration: BoxDecoration(
                              color: _sosActive ? Colors.red.shade900 : AppTheme.colorDanger,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.colorDanger.withOpacity(0.4),
                                  blurRadius: 16,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              'SOS',
                              style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

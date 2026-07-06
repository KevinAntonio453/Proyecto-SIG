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
import 'package:battery_plus/battery_plus.dart';
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

  /// Stream de ubicación en PRIMER PLANO — sin FlutterBackgroundService
  StreamSubscription<Position>? _positionSubscription;
  /// Reconexión periódica del WebSocket
  Timer? _reconnectTimer;

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
    try {
      // 1. Obtener datos del usuario logueado
      final user = await _authService.getCurrentUser();
      if (!mounted) return;
      setState(() => _currentUser = user);

      // 2. Conectar WebSocket
      await _socketService.connect();
      _socketService.marcarOnline();
      if (mounted) {
        setState(() => _isConnected = _socketService.isConnected);
      }

      // Listener de conexión/desconexión
      _socketService.socket?.on('connect', (_) {
        _socketService.marcarOnline();
        if (mounted) setState(() => _isConnected = true);
      });
      _socketService.socket?.on('disconnect', (_) {
        if (mounted) setState(() => _isConnected = false);
      });

      // Reconexión periódica
      _reconnectTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
        if (!_socketService.isConnected) {
          await _socketService.connect();
          _socketService.marcarOnline();
          if (mounted) setState(() => _isConnected = _socketService.isConnected);
        }
      });

      // Callback para cuando el tutor pide ubicación manual
      _socketService.registerLocationRequestCallback((data) async {
        try {
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 5),
          );
          double battery = 100.0;
          try { battery = (await Battery().batteryLevel).toDouble(); } catch (_) {}
          _socketService.enviarUbicacion(
            position.latitude, position.longitude,
            battery: battery, status: 'requested',
          );
        } catch (e) {
          print('❌ [StatusScreen] Error en ubicación caliente: $e');
        }
      });

      // 3. Iniciar stream de ubicación en PRIMER PLANO
      await _iniciarGpsStream();
    } catch (e) {
      print('❌ [HijoStatusScreen] Error al inicializar servicios: $e');
      if (mounted) {
        setState(() => _gpsStatus = 'Error al inicializar. Reinicia la app.');
      }
    }
  }

  /// Abre un stream de posición directamente con Geolocator.
  /// NO usa FlutterBackgroundService. Funciona solo mientras la app está abierta.
  Future<void> _iniciarGpsStream() async {
    try {
      // Los permisos ya fueron verificados por HijoDashboardScreen,
      // así que aquí solo abrimos el stream directamente.
      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      );

      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) async {
          if (!mounted) return;
          setState(() {
            _currentPosition = position;
            _gpsStatus = 'Ubicación: ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
          });

          // Obtener batería
          double battery = 100.0;
          try { battery = (await Battery().batteryLevel).toDouble(); } catch (_) {}

          // Enviar por WebSocket
          _socketService.enviarUbicacion(
            position.latitude, position.longitude,
            battery: battery,
          );

          // Persistir en la BD
          if (_currentUser != null) {
            final registro = Registro(
              hora: DateTime.now(),
              latitud: position.latitude,
              longitud: position.longitude,
              hijoId: _currentUser!.id,
              fueOffline: false,
            );
            try {
              await _registrosService.registrarUbicacion(registro);
            } catch (e) {
              print('❌ [StatusScreen] Error guardando registro: $e');
            }
          }
        },
        onError: (error) {
          print('❌ [StatusScreen] Error en position stream: $error');
          if (mounted) {
            setState(() => _gpsStatus = 'Error de GPS: $error');
          }
        },
      );

      if (mounted) {
        setState(() => _gpsStatus = 'GPS activo, esperando posición...');
      }
    } catch (e) {
      print('❌ [StatusScreen] Error al iniciar GPS stream: $e');
      if (mounted) {
        setState(() => _gpsStatus = 'Error al iniciar GPS: $e');
      }
    }
  }

  // --- CONTROL DEL BOTÓN SOS ---

  void _iniciarSosPress() {
    if (_sosActive) return;

    _sosTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      setState(() {
        _sosProgress += 0.0167;
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
      setState(() => _sosProgress = 0.0);
    }
  }

  Future<void> _triggerSos() async {
    if (_currentUser == null) return;

    setState(() => _sosActive = true);

    try {
      // Enviar SOS con ubicación actual por WebSocket
      if (_currentPosition != null) {
        _socketService.emitirAlertaPanic(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        );
      }
      // Registrar SOS por HTTP
      await _hijosService.enviarSOS(_currentUser!.id);
      _showSosSuccessDialog();
    } catch (e) {
      _showSosErrorSnackBar(e.toString());
    }
  }

  void _showSosSuccessDialog() {
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
              if (mounted) {
                setState(() {
                  _sosActive = false;
                  _sosProgress = 0.0;
                });
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.colorDanger),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  void _showSosErrorSnackBar(String error) {
    if (!mounted) return;
    setState(() {
      _sosActive = false;
      _sosProgress = 0.0;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error enviando SOS: $error'),
        backgroundColor: AppTheme.colorDanger,
      ),
    );
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _reconnectTimer?.cancel();
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
              _socketService.disconnect();
              await _authService.logout();
              if (context.mounted) {
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
                        : AppTheme.colorDanger.withOpacity(0.3),
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

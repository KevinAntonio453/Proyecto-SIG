import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import '../../app/theme.dart';
import '../../core/models/user.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/hijos_service.dart';
import '../auth/welcome_screen.dart';

class HijoStatusScreen extends StatefulWidget {
  const HijoStatusScreen({super.key});

  @override
  State<HijoStatusScreen> createState() => _HijoStatusScreenState();
}

class _HijoStatusScreenState extends State<HijoStatusScreen> {
  final _authService = AuthService();
  final _hijosService = HijosService();

  User? _currentUser;
  bool _isConnected = false;
  String _gpsStatus = 'Inicializando GPS...';
  Position? _currentPosition;
  StreamSubscription? _serviceSubscription;

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
      setState(() {
        _currentUser = user;
      });

      // 2. Inicializar GPS y levantar servicio si es necesario
      await _iniciarGps();
      if (!mounted) return;

      // 3. Suscribirse a los eventos del servicio en segundo plano
      final service = FlutterBackgroundService();

      _serviceSubscription = service.on('update').listen((event) {
        if (mounted && event != null) {
          setState(() {
            final lat = event['latitude'] as double?;
            final lng = event['longitude'] as double?;
            if (lat != null && lng != null) {
              _currentPosition = Position(
                latitude: lat,
                longitude: lng,
                timestamp: DateTime.now(),
                accuracy: 0.0,
                altitude: 0.0,
                altitudeAccuracy: 0.0,
                heading: 0.0,
                headingAccuracy: 0.0,
                speed: 0.0,
                speedAccuracy: 0.0,
              );
            }
            _gpsStatus = event['gpsStatus'] as String? ?? 'GPS Activo';
          });
        }
      });

      service.on('status').listen((event) {
        if (mounted && event != null) {
          setState(() {
            _isConnected = event['isConnected'] as bool? ?? false;
          });
        }
      });

      service.on('sosSent').listen((event) {
        if (mounted && event != null) {
          final success = event['success'] as bool? ?? false;
          if (success) {
            _showSosSuccessDialog();
          } else {
            final error = event['error'] as String? ?? 'Error desconocido';
            _showSosErrorSnackBar(error);
          }
        }
      });

      // Consultar estado actual inicial
      service.invoke('queryStatus');
    } catch (e) {
      print('❌ [HijoStatusScreen] Error al inicializar servicios: $e');
      // No crashear - simplemente mostrar estado degradado
      if (mounted) {
        setState(() {
          _gpsStatus = 'Error al inicializar. Reinicia la app.';
        });
      }
    }
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

    // 1. Solicitar permisos de ubicación en primer plano (Mientras la app está en uso)
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) setState(() => _gpsStatus = 'Permisos de ubicación denegados.');
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      if (mounted) setState(() => _gpsStatus = 'Permisos de ubicación denegados permanentemente. Abrí los ajustes para habilitarlos.');
      await Geolocator.openAppSettings();
      return;
    }

    // 2. Si solo tiene "Mientras la app está en uso", pedir "Permitir siempre"
    //    CRÍTICO: NO arrancar el servicio con solo whileInUse.
    //    En Android 14+ (API 34) iniciar un ForegroundService con tipo "location"
    //    sin ACCESS_BACKGROUND_LOCATION causa un SecurityException FATAL.
    if (permission == LocationPermission.whileInUse) {
      if (mounted) {
        final goToSettings = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Permiso en segundo plano requerido'),
            content: const Text(
                'SafeSteps necesita acceder a tu ubicación "Todo el tiempo" para poder '
                'actualizar tu posición a tus tutores incluso cuando cerrás la aplicación '
                'o bloqueás la pantalla.\n\n'
                'En la siguiente pantalla de ajustes, seleccioná "Permitir siempre".'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Ir a Ajustes'),
              ),
            ],
          ),
        ) ?? false;

        if (goToSettings) {
          await Geolocator.openAppSettings();
        }

        setState(() => _gpsStatus = 'Esperando permiso "Permitir siempre"...');
      }
      // NO arrancar el servicio. El usuario debe volver a abrir la app
      // después de conceder el permiso en los ajustes de Android.
      return;
    }

    // 3. Solo llegamos aquí si permission == LocationPermission.always
    //    Ahora es SEGURO arrancar el servicio de ubicación en segundo plano.
    try {
      final service = FlutterBackgroundService();
      final isRunning = await service.isRunning();
      if (!isRunning) {
        await service.startService();
      }
      service.invoke('queryStatus');
    } catch (e) {
      print('❌ [HijoStatusScreen] Error al iniciar servicio de ubicación: $e');
      if (mounted) {
        setState(() => _gpsStatus = 'Error al iniciar el servicio de ubicación.');
      }
    }
  }

  // --- CONTROL DEL BOTÓN SOS ---

  void _iniciarSosPress() {
    if (_sosActive) return;

    _sosTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      setState(() {
        _sosProgress += 0.0167; // Aumentar hasta llegar a 1.0 en ~3 segundos
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
    if (_currentUser == null) return;

    setState(() {
      _sosActive = true;
    });

    try {
      // 1. Invocar SOS por WebSocket en segundo plano
      final service = FlutterBackgroundService();
      service.invoke('triggerSos');

      // 2. Registrar SOS por HTTP
      await _hijosService.enviarSOS(_currentUser!.id);
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
    _serviceSubscription?.cancel();
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
              final service = FlutterBackgroundService();
              final isRunning = await service.isRunning();
              if (isRunning) {
                service.invoke('stopService');
              }
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

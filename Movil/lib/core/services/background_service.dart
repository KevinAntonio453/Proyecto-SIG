import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'socket_service.dart';
import 'registros_service.dart';
import '../models/registro.dart';
import 'auth_service.dart';

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false, // Se inicia al iniciar sesión como Hijo
      isForegroundMode: true,
      notificationChannelId: 'safesteps_location_channel',
      initialNotificationTitle: 'SafeSteps',
      initialNotificationContent: 'Rastreo de ubicación activo en segundo plano',
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onForeground,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  Position? lastPosition;

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  // Limpieza al detener el servicio
  service.on('stopService').listen((event) async {
    print('🔌 [BackgroundService] Deteniendo servicio de ubicación.');
    final socketService = SocketService();
    socketService.marcarOffline();
    socketService.disconnect();
    service.stopSelf();
  });

  print('🔌 [BackgroundService] Inicializando servicio en segundo plano...');

  // Inicializar servicios internos
  final socketService = SocketService();
  final registrosService = RegistrosService();
  final authService = AuthService();

  // Intentar conectar el socket
  await socketService.connect();
  socketService.marcarOnline();

  // Obtener datos del usuario hijo autenticado
  final user = await authService.getCurrentUser();

  // Escuchar eventos de conexión del socket para avisar a la UI
  socketService.socket?.on('connect', (_) {
    socketService.marcarOnline();
    service.invoke('status', {'isConnected': true});
  });
  
  socketService.socket?.on('disconnect', (_) {
    service.invoke('status', {'isConnected': false});
  });

  // Atender consultas de estado desde la UI
  service.on('queryStatus').listen((event) {
    service.invoke('status', {
      'isConnected': socketService.isConnected,
    });
    if (lastPosition != null) {
      service.invoke('update', {
        'latitude': lastPosition!.latitude,
        'longitude': lastPosition!.longitude,
        'gpsStatus': 'Ubicación: ${lastPosition!.latitude.toStringAsFixed(5)}, ${lastPosition!.longitude.toStringAsFixed(5)}',
      });
    }
  });

  // Escuchar cuando el tutor solicita ubicación manual en caliente
  socketService.registerLocationRequestCallback((data) async {
    print('🔌 [BackgroundService] Tutor solicitó ubicación manual en caliente.');
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
      lastPosition = position;
      socketService.enviarUbicacion(
        position.latitude,
        position.longitude,
        status: 'requested',
      );
      service.invoke('update', {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'gpsStatus': 'Ubicación en caliente enviada',
      });
    } catch (e) {
      print('🔌 [BackgroundService] Error obteniendo ubicación en caliente: $e');
    }
  });

  // Escuchar cuando la interfaz solicita disparar un SOS
  service.on('triggerSos').listen((event) async {
    print('🔌 [BackgroundService] Alerta SOS solicitada por la interfaz.');
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      lastPosition = position;
      socketService.emitirAlertaPanic(position.latitude, position.longitude);
      service.invoke('sosSent', {'success': true});
    } catch (e) {
      service.invoke('sosSent', {'success': false, 'error': e.toString()});
    }
  });

  // Configurar el Stream del GPS
  const LocationSettings locationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 5, // Notificar cada 5 metros
  );

  StreamSubscription<Position>? positionSubscription;

  positionSubscription = Geolocator.getPositionStream(
    locationSettings: locationSettings,
  ).listen((Position position) async {
    lastPosition = position;

    // 1. Transmitir por WebSocket en tiempo real
    socketService.enviarUbicacion(position.latitude, position.longitude);

    // 2. Persistir en la base de datos vía API HTTP (Historial de Trayectorias)
    if (user != null) {
      try {
        await registrosService.registrarUbicacion(
          Registro(
            hora: DateTime.now(),
            latitud: position.latitude,
            longitud: position.longitude,
            hijoId: user.id,
            fueOffline: false,
          ),
        );
      } catch (e) {
        print('🔌 [BackgroundService] Error al guardar registro HTTP: $e');
      }
    }

    // 3. Actualizar la notificación persistente de Android
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        service.setForegroundNotificationInfo(
          title: 'SafeSteps Activo',
          content: 'Ubicación: ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}',
        );
      }
    }

    // 4. Enviar los datos a la interfaz de usuario en primer plano (si está abierta)
    service.invoke('update', {
      'latitude': position.latitude,
      'longitude': position.longitude,
      'gpsStatus': 'Ubicación: ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}',
    });
  });

  // Monitorear y mantener viva la conexión WebSocket cada 30 segundos
  Timer.periodic(const Duration(seconds: 30), (timer) async {
    if (!socketService.isConnected) {
      print('🔌 [BackgroundService] Socket desconectado. Intentando reconectar...');
      await socketService.connect();
      socketService.marcarOnline();
      service.invoke('status', {'isConnected': socketService.isConnected});
    }
  });
}

@pragma('vm:entry-point')
bool onIosBackground(ServiceInstance service) {
  WidgetsFlutterBinding.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onForeground(ServiceInstance service) {
  WidgetsFlutterBinding.ensureInitialized();
}

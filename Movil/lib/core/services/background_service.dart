import 'dart:async';
import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
      
      double batteryLevel = 100.0;
      try {
        final level = await Battery().batteryLevel;
        batteryLevel = level.toDouble();
      } catch (e) {
        print('Error al obtener batería caliente: $e');
      }

      socketService.enviarUbicacion(
        position.latitude,
        position.longitude,
        battery: batteryLevel,
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

    double batteryLevel = 100.0;
    try {
      final level = await Battery().batteryLevel;
      batteryLevel = level.toDouble();
    } catch (e) {
      print('Error al obtener batería: $e');
    }

    // 1. Transmitir por WebSocket en tiempo real con nivel de batería real
    socketService.enviarUbicacion(
      position.latitude, 
      position.longitude,
      battery: batteryLevel,
    );

    // 2. Persistir en la base de datos vía API HTTP (Historial de Trayectorias)
    if (user != null) {
      final registro = Registro(
        hora: DateTime.now(),
        latitud: position.latitude,
        longitud: position.longitude,
        hijoId: user.id,
        fueOffline: false,
      );

      try {
        await registrosService.registrarUbicacion(registro);
        // Si tiene éxito, intentamos sincronizar cualquier registro offline acumulado
        await _intentarSincronizarOffline(user.id, registrosService);
      } catch (e) {
        print('🔌 [BackgroundService] Error al guardar registro HTTP (guardando localmente): $e');
        final registroOffline = Registro(
          hora: registro.hora,
          latitud: registro.latitud,
          longitud: registro.longitud,
          hijoId: registro.hijoId,
          fueOffline: true,
        );
        await _guardarRegistroOffline(registroOffline);
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

    // Si hay usuario e internet, intentamos sincronizar registros offline pendientes
    if (user != null && socketService.isConnected) {
      await _intentarSincronizarOffline(user.id, registrosService);
    }
  });
}

Future<void> _guardarRegistroOffline(Registro registro) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final List<String> offlineList = prefs.getStringList('offline_locations') ?? [];
    offlineList.add(jsonEncode(registro.toJson()));
    await prefs.setStringList('offline_locations', offlineList);
    print('🔌 [BackgroundService] Guardado registro offline localmente. Total acumulado: ${offlineList.length}');
  } catch (e) {
    print('Error al guardar registro offline localmente: $e');
  }
}

Future<void> _intentarSincronizarOffline(int hijoId, RegistrosService registrosService) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final List<String> offlineList = prefs.getStringList('offline_locations') ?? [];
    if (offlineList.isEmpty) return;

    print('🔌 [BackgroundService] Detectada conexión. Sincronizando ${offlineList.length} registros offline...');
    final List<Registro> registros = offlineList.map((item) {
      final json = jsonDecode(item) as Map<String, dynamic>;
      json['hijoId'] = hijoId;
      return Registro.fromJson(json);
    }).toList();

    await registrosService.sincronizarOffline(hijoId, registros);
    await prefs.remove('offline_locations');
    print('🔌 [BackgroundService] Sincronización offline completada con éxito.');
  } catch (e) {
    print('🔌 [BackgroundService] Error al intentar sincronizar offline: $e');
  }
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

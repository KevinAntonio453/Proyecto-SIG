import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Inicializa Firebase para poder usarlo en segundo plano al recibir pushes
  await Firebase.initializeApp();
  if (kDebugMode) {
    print("📲 [FCM Background] Alerta en segundo plano: ${message.messageId}");
  }
}

class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  // Inicializa FCM, solicita permisos y suscribe los listeners
  static Future<void> initialize() async {
    try {
      // 1. Inicializar Firebase Core (usa el archivo google-services.json que copiamos)
      await Firebase.initializeApp();

      // 2. Registrar el manejador de segundo plano / app cerrada
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 3. Solicitar permisos de notificaciones (Android 13+ / iOS)
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (kDebugMode) {
        print('📲 [FCM] Autorización de notificaciones: ${settings.authorizationStatus}');
      }

      // 4. Registrar token inicial en el servidor si hay una sesión activa
      await updateTokenOnServer();

      // 5. Escuchar refrescos del token FCM
      messaging.onTokenRefresh.listen((newToken) async {
        if (kDebugMode) {
          print('📲 [FCM] Token refrescado: $newToken');
        }
        final authService = AuthService();
        final currentUser = await authService.getCurrentUser();
        if (currentUser != null) {
          await authService.updateFcmToken(newToken);
        }
      });

      // 6. Escuchar notificaciones recibidas en primer plano (Foreground)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (kDebugMode) {
          print('📲 [FCM Foreground] Mensaje recibido: ${message.notification?.title} - ${message.notification?.body}');
        }
      });

    } catch (e) {
      if (kDebugMode) {
        print('📲 [FCM] Error de inicialización: $e');
      }
    }
  }

  // Obtiene el token de este dispositivo y lo sube al servidor si hay un usuario logueado
  static Future<void> updateTokenOnServer() async {
    try {
      final authService = AuthService();
      final currentUser = await authService.getCurrentUser();
      if (currentUser != null) {
        final fcmToken = await FirebaseMessaging.instance.getToken();
        if (fcmToken != null) {
          if (kDebugMode) {
            print('📲 [FCM] Token actual del dispositivo: $fcmToken');
          }
          await authService.updateFcmToken(fcmToken);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('📲 [FCM] Error subiendo token al servidor: $e');
      }
    }
  }
}

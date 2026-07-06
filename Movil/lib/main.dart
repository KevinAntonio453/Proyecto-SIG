import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/theme.dart';
import 'core/constants/app_constants.dart';
import 'core/services/auth_service.dart';
import 'core/services/background_service.dart';
import 'core/services/fcm_service.dart';
import 'core/services/api_client.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'features/auth/welcome_screen.dart';
import 'features/tutor/dashboard_screen.dart';
import 'features/hijo/dashboard_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() async {
  // Zona de seguridad global: atrapa CUALQUIER error async no capturado
  // para que la app nunca se cierre sin razón visible.
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Inicializar Firebase y Notificaciones Push (FCM)
    await FcmService.initialize();

    // Inicializar configuraciones del servicio en segundo plano
    await initializeBackgroundService();

    // --- Validar sesión almacenada ANTES de decidir la pantalla inicial ---
    final authService = AuthService();
    dynamic currentUser;
    String? userType;

    try {
      currentUser = await authService.getCurrentUser();
      userType = await authService.getUserType();

      // Si hay sesión guardada, verificar que el token JWT no haya expirado
      if (currentUser != null) {
        final tokenValid = await authService.isTokenValid();
        if (!tokenValid) {
          print('⚠️ [main] Token JWT expirado. Limpiando sesión local.');
          await authService.logout();
          // Detener servicio de ubicación si estaba corriendo
          try {
            final service = FlutterBackgroundService();
            final isRunning = await service.isRunning();
            if (isRunning) {
              service.invoke('stopService');
            }
          } catch (_) {}
          currentUser = null;
          userType = null;
        }
      }
    } catch (e) {
      print('❌ [main] Error al cargar la sesión. Limpiando datos corruptos: $e');
      await authService.logout();
      currentUser = null;
      userType = null;
    }

    // Configurar interceptor global de sesión expirada (401) con debounce
    bool isHandlingUnauthorized = false;

    ApiClient.onUnauthorized = () async {
      // Evitar que se dispare múltiples veces simultáneamente
      if (isHandlingUnauthorized) return;
      isHandlingUnauthorized = true;

      try {
        final bgService = FlutterBackgroundService();
        final isRunning = await bgService.isRunning();
        if (isRunning) {
          bgService.invoke('stopService');
        }
      } catch (_) {}

      scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('Sesión expirada. Por favor, inicia sesión de nuevo.'),
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 4),
        ),
      );

      // Esperar un frame para que el árbol de widgets esté estable
      WidgetsBinding.instance.addPostFrameCallback((_) {
        navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const WelcomeScreen()),
          (route) => false,
        );
        // Permitir volver a disparar después de 3 segundos
        Future.delayed(const Duration(seconds: 3), () {
          isHandlingUnauthorized = false;
        });
      });
    };

    runApp(
      ProviderScope(
        child: MyApp(
          initialScreen: _getInitialScreen(currentUser, userType),
        ),
      ),
    );
  }, (error, stack) {
    // Red de seguridad: loggear errores globales no capturados sin cerrar la app
    print('❌ [Global] Error no capturado: $error');
    print(stack);
  });
}

// Captura errores de Flutter (rendering, layout, etc.)
class MyApp extends StatelessWidget {
  final Widget initialScreen;

  const MyApp({super.key, required this.initialScreen});

  @override
  Widget build(BuildContext context) {
    // Sobreescribir el manejador de errores de Flutter para evitar crashes visuales
    FlutterError.onError = (FlutterErrorDetails details) {
      print('❌ [FlutterError] ${details.exceptionAsString()}');
      print(details.stack);
    };

    return MaterialApp(
      title: AppConstants.appName,
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: scaffoldMessengerKey,
      home: initialScreen,
    );
  }
}

Widget _getInitialScreen(dynamic user, String? type) {
  if (user == null) {
    return const WelcomeScreen();
  }
  if (type == 'hijo') {
    return const HijoDashboardScreen();
  }
  return const TutorDashboardScreen();
}

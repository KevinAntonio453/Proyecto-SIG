import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/theme.dart';
import 'core/constants/app_constants.dart';
import 'core/services/auth_service.dart';
import 'features/auth/welcome_screen.dart';
import 'features/tutor/dashboard_screen.dart';
import 'features/hijo/dashboard_screen.dart';

void main() async {
  // Asegurar la inicialización de bindings asíncronos en Flutter
  WidgetsFlutterBinding.ensureInitialized();
  
  final authService = AuthService();
  final currentUser = await authService.getCurrentUser();
  final userType = await authService.getUserType();

  runApp(
    ProviderScope(
      child: MyApp(
        initialScreen: _getInitialScreen(currentUser, userType),
      ),
    ),
  );
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

class MyApp extends StatelessWidget {
  final Widget initialScreen;

  const MyApp({super.key, required this.initialScreen});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: initialScreen,
    );
  }
}

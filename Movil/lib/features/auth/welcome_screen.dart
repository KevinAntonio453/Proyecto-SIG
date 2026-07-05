import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../core/constants/app_constants.dart';
import 'login_screen.dart';
import 'vincular_screen.dart';
import 'register_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // Logo e Icono Principal
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryTealSurface,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.security_outlined,
                    size: 56,
                    color: AppTheme.primaryTeal,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Título de la Aplicación
              Text(
                AppConstants.appName,
                style: textTheme.displayLarge?.copyWith(
                  color: AppTheme.primaryTeal,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              // Eslogan / Descripción
              Text(
                'Monitoreo infantil inteligente y geocercas en tiempo real para la tranquilidad de tu familia.',
                style: textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              // Botón Iniciar Sesión (Tutor)
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                  );
                },
                child: const Text('Iniciar Sesión como Tutor'),
              ),
              const SizedBox(height: 12),
              // Botón Registrarse (Tutor)
              OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const RegisterScreen()),
                  );
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: AppTheme.primaryTeal),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Registrarse como Tutor',
                  style: textTheme.labelLarge?.copyWith(color: AppTheme.primaryTeal),
                ),
              ),
              const SizedBox(height: 24),
              // Separador Visual
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('O SI SOS UN HIJO'),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 24),
              // Botón Ingresar Código (Hijo)
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const VincularScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.secondaryCoral,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Ingresar Código de Vinculación'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

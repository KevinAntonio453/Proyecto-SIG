import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../../app/theme.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/fcm_service.dart';
import '../../core/constants/app_constants.dart';
import '../hijo/dashboard_screen.dart'; // Pantalla home/dashboard del hijo

class VincularScreen extends StatefulWidget {
  const VincularScreen({super.key});

  @override
  State<VincularScreen> createState() => _VincularScreenState();
}

class _VincularScreenState extends State<VincularScreen> {
  final _authService = AuthService();
  final _codeController = TextEditingController();

  bool _isLoading = false;
  String _errorMessage = '';

  Future<void> _loginConCodigo() async {
    final codigo = _codeController.text.trim();
    if (codigo.length != 6) {
      setState(() => _errorMessage = 'El código debe tener exactamente 6 caracteres.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final user = await _authService.loginConCodigo(codigo);
      
      if (!mounted) return;
      
      // Registrar el token FCM del dispositivo en el servidor para el hijo
      await FcmService.updateTokenOnServer();

      if (!mounted) return;

      // Levantar el servicio en segundo plano para rastrear al hijo
      final service = FlutterBackgroundService();
      final isRunning = await service.isRunning();
      if (!isRunning) {
        await service.startService();
      }

      if (!mounted) return;

      // Mostrar feedback y navegar al dashboard del hijo
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡Inicio de sesión exitoso! Bienvenido ${user.nombre}'),
          backgroundColor: AppTheme.colorSafe,
        ),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HijoDashboardScreen()),
        (route) => false,
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ingresar como Hijo'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              // Icono explicativo
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryTealSurface,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.phonelink_setup_outlined,
                    size: 40,
                    color: AppTheme.primaryTeal,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              if (_errorMessage.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.colorDanger.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.colorDanger.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppTheme.colorDanger),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage,
                          style: textTheme.bodyMedium?.copyWith(color: AppTheme.colorDanger),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              Text(
                'Ingresá tu código',
                style: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Pedile a tu tutor el código de 6 caracteres que generó en su aplicación.',
                style: textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _codeController,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                  color: AppTheme.primaryTeal,
                ),
                decoration: const InputDecoration(
                  hintText: 'A3B7K9',
                  counterText: '',
                ),
                textCapitalization: TextCapitalization.characters,
                autofocus: true,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _loginConCodigo,
                child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : const Text('Iniciar Sesión'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

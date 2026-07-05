import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../core/services/auth_service.dart';
import '../../core/constants/app_constants.dart';
import '../hijo/status_screen.dart'; // Pantalla home del hijo una vez conectado

class VincularScreen extends StatefulWidget {
  const VincularScreen({super.key});

  @override
  State<VincularScreen> createState() => _VincularScreenState();
}

class _VincularScreenState extends State<VincularScreen> {
  final _authService = AuthService();
  final _codeController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  int _step = 1; // Paso 1: ingresar código, Paso 2: ingresar credenciales
  bool _isLoading = false;
  String _errorMessage = '';
  
  // Datos devueltos por el código verificado
  String _hijoNombre = '';
  String _hijoApellido = '';

  // Paso 1: Verificar el código alfanumérico
  Future<void> _verificarCodigo() async {
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
      final info = await _authService.verificarCodigo(codigo);
      if (info['vinculado'] == true) {
        setState(() {
          _errorMessage = 'Este dispositivo/código ya está vinculado a una cuenta.';
          _isLoading = false;
        });
        return;
      }
      setState(() {
        _hijoNombre = info['nombre'] as String? ?? '';
        _hijoApellido = info['apellido'] as String? ?? '';
        _step = 2;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  // Paso 2: Vincular y crear usuario
  Future<void> _completarVinculacion() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final codigo = _codeController.text.trim();
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      final user = await _authService.vincularHijo(codigo, email, password);
      
      if (!mounted) return;
      
      // Mostrar feedback y navegar al home del hijo
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡Vinculación exitosa! Bienvenido ${user.nombre}'),
          backgroundColor: AppTheme.colorSafe,
        ),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HijoStatusScreen()),
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
        title: const Text('Vincular Dispositivo'),
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

              // PASO 1: Ingreso de Código
              if (_step == 1) ...[
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
                  onPressed: _isLoading ? null : _verificarCodigo,
                  child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white) 
                      : const Text('Verificar Código'),
                ),
              ],

              // PASO 2: Confirmar datos y crear cuenta
              if (_step == 2) ...[
                Text(
                  '¿Sos $_hijoNombre $_hijoApellido?',
                  style: textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryTeal,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Confirmá tu identidad y configurá tus credenciales finales de acceso.',
                  style: textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Correo Electrónico Definitivo',
                          hintText: 'ejemplo@correo.com',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor ingresá un correo.';
                          }
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                            return 'Formato de correo inválido.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Contraseña de Acceso',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor ingresá una contraseña.';
                          }
                          if (value.length < 6) {
                            return 'La contraseña debe tener mínimo 6 caracteres.';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isLoading ? null : _completarVinculacion,
                  child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white) 
                      : const Text('Confirmar y Vincular'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _step = 1;
                      _codeController.clear();
                    });
                  },
                  child: const Text('Volver atrás'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

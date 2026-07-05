import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../core/models/hijo.dart';
import '../../core/services/hijos_service.dart';

class RegisterChildScreen extends StatefulWidget {
  const RegisterChildScreen({super.key});

  @override
  State<RegisterChildScreen> createState() => _RegisterChildScreenState();
}

class _RegisterChildScreenState extends State<RegisterChildScreen> {
  final _hijosService = HijosService();
  final _formKey = GlobalKey<FormState>();
  
  final _nombreController = TextEditingController();
  final _apellidoController = TextEditingController();
  final _telefonoController = TextEditingController();

  bool _isLoading = false;
  String _errorMessage = '';

  Future<void> _registrarHijo() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final nombre = _nombreController.text.trim();
      final apellido = _apellidoController.text.trim().isEmpty ? null : _apellidoController.text.trim();
      final telefono = _telefonoController.text.trim().isEmpty ? null : _telefonoController.text.trim();

      final nuevoHijo = await _hijosService.registrarHijo(
        nombre,
        apellido: apellido,
        telefono: telefono,
      );

      if (!mounted) return;

      // Cerrar la pantalla y devolver el hijo registrado para mostrar su código
      Navigator.pop(context, nuevoHijo);
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
        title: const Text('Registrar Hijo'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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

                // Campo Nombre
                TextFormField(
                  controller: _nombreController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del Menor',
                    prefixIcon: Icon(Icons.person_outline),
                    hintText: 'Ej. Juan',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingresá el nombre.';
                    }
                    if (value.length < 3) {
                      return 'Mínimo 3 caracteres.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Campo Apellido
                TextFormField(
                  controller: _apellidoController,
                  decoration: const InputDecoration(
                    labelText: 'Apellido (Opcional)',
                    prefixIcon: Icon(Icons.badge_outlined),
                    hintText: 'Ej. Pérez',
                  ),
                  validator: (value) {
                    if (value != null && value.isNotEmpty && value.length < 2) {
                      return 'Mínimo 2 caracteres.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Campo Teléfono
                TextFormField(
                  controller: _telefonoController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono de Contacto (Opcional)',
                    prefixIcon: Icon(Icons.phone_outlined),
                    hintText: 'Ej. 70012345',
                  ),
                  validator: (value) {
                    if (value != null && value.isNotEmpty && value.length < 7) {
                      return 'Mínimo 7 dígitos.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                // Botón Guardar
                ElevatedButton(
                  onPressed: _isLoading ? null : _registrarHijo,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Registrar Hijo'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

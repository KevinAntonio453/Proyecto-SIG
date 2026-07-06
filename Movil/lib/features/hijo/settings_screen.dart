import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../app/theme.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/socket_service.dart';
import '../../core/models/user.dart';
import '../auth/welcome_screen.dart';

class HijoSettingsScreen extends StatefulWidget {
  const HijoSettingsScreen({super.key});

  @override
  State<HijoSettingsScreen> createState() => _HijoSettingsScreenState();
}

class _HijoSettingsScreenState extends State<HijoSettingsScreen> {
  final _authService = AuthService();
  User? _currentUser;
  bool _gpsEnabled = false;
  LocationPermission _locationPermission = LocationPermission.denied;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      final user = await _authService.getCurrentUser();
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      final permission = await Geolocator.checkPermission();

      if (mounted) {
        setState(() {
          _currentUser = user;
          _gpsEnabled = serviceEnabled;
          _locationPermission = permission;
        });
      }
    } catch (e) {
      debugPrint('Error al cargar datos de settings: $e');
    }
  }

  String _permissionLabel(LocationPermission p) {
    switch (p) {
      case LocationPermission.always:
        return 'Permitido siempre';
      case LocationPermission.whileInUse:
        return 'Mientras se usa la app';
      case LocationPermission.denied:
        return 'Denegado';
      case LocationPermission.deniedForever:
        return 'Denegado permanentemente';
      case LocationPermission.unableToDetermine:
        return 'No determinado';
    }
  }

  Color _permissionColor(LocationPermission p) {
    switch (p) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return AppTheme.colorSafe;
      case LocationPermission.denied:
        return AppTheme.colorWarning;
      case LocationPermission.deniedForever:
        return AppTheme.colorDanger;
      case LocationPermission.unableToDetermine:
        return AppTheme.colorOffline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Datos del hijo
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppTheme.primaryTealSurface,
                    child: const Icon(Icons.person, size: 30, color: AppTheme.primaryTeal),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentUser?.nombre ?? 'Cargando...',
                          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (_currentUser?.email != null)
                          Text(
                            _currentUser!.email!,
                            style: textTheme.bodyMedium,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 2. Estado de permisos
          Text(
            'Estado de Permisos',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // GPS habilitado
          Card(
            child: ListTile(
              leading: Icon(
                _gpsEnabled ? Icons.gps_fixed : Icons.gps_off,
                color: _gpsEnabled ? AppTheme.colorSafe : AppTheme.colorDanger,
              ),
              title: const Text('Servicios de Ubicación'),
              subtitle: Text(_gpsEnabled ? 'Activado' : 'Desactivado'),
              trailing: !_gpsEnabled
                  ? TextButton(
                      onPressed: () => Geolocator.openLocationSettings(),
                      child: const Text('Activar'),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 8),

          // Permiso de ubicación
          Card(
            child: ListTile(
              leading: Icon(
                Icons.location_on,
                color: _permissionColor(_locationPermission),
              ),
              title: const Text('Permiso de Ubicación'),
              subtitle: Text(_permissionLabel(_locationPermission)),
              trailing: (_locationPermission == LocationPermission.denied ||
                         _locationPermission == LocationPermission.deniedForever)
                  ? TextButton(
                      onPressed: () => Geolocator.openAppSettings(),
                      child: const Text('Abrir Ajustes'),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 32),

          // 3. Cerrar Sesión
          ElevatedButton.icon(
            onPressed: () async {
              final socketService = SocketService();
              socketService.marcarOffline();
              socketService.disconnect();
              await _authService.logout();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const WelcomeScreen()),
                  (route) => false,
                );
              }
            },
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar Sesión'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.colorDanger,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }
}

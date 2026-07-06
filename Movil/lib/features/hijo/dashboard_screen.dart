import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../app/theme.dart';
import '../../core/services/socket_service.dart';
import 'status_screen.dart';
import 'location_screen.dart';
import 'settings_screen.dart';

class HijoDashboardScreen extends StatefulWidget {
  const HijoDashboardScreen({super.key});

  @override
  State<HijoDashboardScreen> createState() => _HijoDashboardScreenState();
}

class _HijoDashboardScreenState extends State<HijoDashboardScreen> {
  int _currentIndex = 0;

  /// Permiso resuelto UNA sola vez antes de construir cualquier pestaña.
  /// null = todavía resolviendo, false = no concedido, true = listo.
  bool? _permissionReady;
  String _permissionMessage = 'Verificando permisos de ubicación...';

  @override
  void initState() {
    super.initState();
    _resolvePermissions();
  }

  /// Centraliza TODA la verificación de permisos de ubicación.
  /// Las pantallas hijas ya NO llaman a Geolocator.checkPermission/requestPermission.
  Future<void> _resolvePermissions() async {
    try {
      // 1. ¿Servicios de ubicación activos?
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _permissionReady = false;
            _permissionMessage = 'Los servicios de ubicación están desactivados.';
          });
        }
        return;
      }

      // 2. Chequear permiso actual
      var permission = await Geolocator.checkPermission();

      // 3. Si está denegado, solicitar
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            setState(() {
              _permissionReady = false;
              _permissionMessage = 'Permiso de ubicación denegado.';
            });
          }
          return;
        }
      }

      // 4. Denegado permanentemente
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _permissionReady = false;
            _permissionMessage = 'Permiso de ubicación denegado permanentemente. Abrí los ajustes para habilitarlo.';
          });
          await Geolocator.openAppSettings();
        }
        return;
      }

      // 5. whileInUse o always → suficiente para funcionar en primer plano
      if (mounted) {
        setState(() {
          _permissionReady = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _permissionReady = false;
          _permissionMessage = 'Error al verificar permisos: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Mientras resolvemos permisos, mostrar loader
    if (_permissionReady == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppTheme.primaryTeal),
              const SizedBox(height: 24),
              Text(
                _permissionMessage,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      );
    }

    // Si los permisos no se concedieron, pantalla de error con reintentar
    if (_permissionReady == false) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_off, size: 64, color: AppTheme.colorDanger),
                const SizedBox(height: 24),
                Text(
                  _permissionMessage,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () {
                    setState(() {
                      _permissionReady = null;
                      _permissionMessage = 'Verificando permisos de ubicación...';
                    });
                    _resolvePermissions();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => Geolocator.openAppSettings(),
                  icon: const Icon(Icons.settings),
                  label: const Text('Abrir Ajustes'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Permisos OK → construir las pestañas (solo la activa se monta)
    return Scaffold(
      body: _buildScreen(_currentIndex),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.primaryTeal,
        unselectedItemColor: AppTheme.onSurfaceVariant,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.emergency_outlined),
            activeIcon: Icon(Icons.emergency),
            label: 'Estado',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map),
            label: 'Mi Ubicación',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Ajustes',
          ),
        ],
      ),
    );
  }

  /// Construye SOLO la pantalla activa (lazy). No IndexedStack.
  Widget _buildScreen(int index) {
    switch (index) {
      case 0:
        return const HijoStatusScreen();
      case 1:
        return const HijoLocationScreen();
      case 2:
        return const HijoSettingsScreen();
      default:
        return const HijoStatusScreen();
    }
  }
}

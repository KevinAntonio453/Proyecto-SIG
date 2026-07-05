import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/socket_service.dart';
import '../auth/welcome_screen.dart';
import 'manage_children_screen.dart';
import 'zones/zones_list_screen.dart';
import 'sos_overlay.dart';
import 'home_screen.dart';

class TutorDashboardScreen extends StatefulWidget {
  const TutorDashboardScreen({super.key});

  @override
  State<TutorDashboardScreen> createState() => _TutorDashboardScreenState();
}

class _TutorDashboardScreenState extends State<TutorDashboardScreen> {
  int _currentIndex = 0;
  final _socketService = SocketService();

  // Lista de pantallas asociadas a cada tab
  late final List<Widget> _screens = [
    const TutorHomeScreen(),
    ManageChildrenScreen(onTabChange: (index) {
      setState(() {
        _currentIndex = index;
      });
    }),
    const ZonesListScreen(),
    const ProfileTab(),
  ];

  @override
  void initState() {
    super.initState();
    _iniciarWebSocket();
  }

  Future<void> _iniciarWebSocket() async {
    await _socketService.connect();
    // Escuchar alertas de pánico en tiempo real
    _socketService.registerPanicCallback(_onPanicAlert);
  }

  void _onPanicAlert(Map<String, dynamic> data) {
    if (!mounted) return;
    
    final childName = data['childName'] as String? ?? 'Hijo';
    final lat = (data['lat'] as num?)?.toDouble() ?? 0.0;
    final lng = (data['lng'] as num?)?.toDouble() ?? 0.0;
    final telefono = data['telefono'] as String?;

    SosOverlay.show(
      context: context,
      childName: childName,
      lat: lat,
      lng: lng,
      telefono: telefono,
    );
  }

  @override
  void dispose() {
    _socketService.unregisterPanicCallback(_onPanicAlert);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.primaryTeal,
        unselectedItemColor: AppTheme.onSurfaceVariant,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: 'Familia',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.security_outlined),
            activeIcon: Icon(Icons.security),
            label: 'Zonas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Mi Cuenta',
          ),
        ],
      ),
    );
  }
}

// Subpantalla de perfil con botón de cerrar sesión
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Cuenta'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            Center(
              child: CircleAvatar(
                radius: 50,
                backgroundColor: AppTheme.primaryTealSurface,
                child: const Icon(
                  Icons.person,
                  size: 50,
                  color: AppTheme.primaryTeal,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Tutor Autenticado',
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryTeal,
              ),
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () async {
                await authService.logout();
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
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

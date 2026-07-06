import 'package:flutter/material.dart';
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

  final List<Widget> _screens = [
    const HijoStatusScreen(),
    const HijoLocationScreen(),
    const HijoSettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
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
}

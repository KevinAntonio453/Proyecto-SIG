import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../core/models/notification.dart';
import '../../core/services/notifications_service.dart';

class TutorNotificationsScreen extends StatefulWidget {
  const TutorNotificationsScreen({super.key});

  @override
  State<TutorNotificationsScreen> createState() => _TutorNotificationsScreenState();
}

class _TutorNotificationsScreenState extends State<TutorNotificationsScreen> {
  final _notificationsService = NotificationsService();
  List<AppNotification> _notifications = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _cargarNotificaciones();
  }

  Future<void> _cargarNotificaciones() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final data = await _notificationsService.getNotifications();
      setState(() {
        _notifications = data['notifications'] as List<AppNotification>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _marcarLeida(AppNotification notif) async {
    if (notif.leida) return;
    try {
      await _notificationsService.markAsRead([notif.id]);
      setState(() {
        final idx = _notifications.indexWhere((n) => n.id == notif.id);
        if (idx != -1) {
          _notifications[idx] = AppNotification(
            id: notif.id,
            mensaje: notif.mensaje,
            tipo: notif.tipo,
            leida: true,
            tutorId: notif.tutorId,
            createdAt: notif.createdAt,
          );
        }
      });
    } catch (e) {
      print('Error al marcar leída: $e');
    }
  }

  Future<void> _marcarTodasLeidas() async {
    setState(() => _isLoading = true);
    try {
      await _notificationsService.markAllAsRead();
      await _cargarNotificaciones();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.colorDanger),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _eliminarNotificacion(int id) async {
    try {
      await _notificationsService.eliminarNotificacion(id);
      setState(() {
        _notifications.removeWhere((n) => n.id == id);
      });
    } catch (e) {
      print('Error al eliminar notificación: $e');
    }
  }

  // Obtener icono e icono de color según tipo de notificación
  Widget _getIconoNotificacion(String tipo) {
    IconData iconData;
    Color color;

    switch (tipo) {
      case 'zone_entry':
        iconData = Icons.shield;
        color = AppTheme.colorSafe;
        break;
      case 'zone_exit':
        iconData = Icons.shield_outlined;
        color = AppTheme.colorWarning;
        break;
      case 'sos_panico':
        iconData = Icons.emergency;
        color = AppTheme.colorDanger;
        break;
      default:
        iconData = Icons.notifications;
        color = AppTheme.colorInfo;
    }

    return CircleAvatar(
      backgroundColor: color.withOpacity(0.1),
      child: Icon(iconData, color: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        actions: [
          if (_notifications.any((n) => !n.leida))
            IconButton(
              icon: const Icon(Icons.done_all),
              tooltip: 'Marcar todas como leídas',
              onPressed: _marcarTodasLeidas,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarNotificaciones,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(_errorMessage, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        ElevatedButton(onPressed: _cargarNotificaciones, child: const Text('Reintentar')),
                      ],
                    ),
                  )
                : _notifications.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.notifications_none, size: 80, color: AppTheme.colorOffline),
                              const SizedBox(height: 16),
                              Text(
                                'No hay notificaciones',
                                style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Aquí verás las alertas cuando tus hijos entren o salgan de sus zonas, o si activan el SOS.',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _cargarNotificaciones,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _notifications.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final notif = _notifications[index];
                            final timeStr = "${notif.createdAt.hour.toString().padLeft(2, '0')}:${notif.createdAt.minute.toString().padLeft(2, '0')}";

                            return Dismissible(
                              key: Key(notif.id.toString()),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                decoration: BoxDecoration(
                                  color: AppTheme.colorDanger,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.delete, color: Colors.white),
                              ),
                              onDismissed: (direction) => _eliminarNotificacion(notif.id),
                              child: Card(
                                color: notif.leida ? Colors.white : AppTheme.primaryTealSurface.withOpacity(0.3),
                                child: ListTile(
                                  onTap: () => _marcarLeida(notif),
                                  leading: _getIconoNotificacion(notif.tipo),
                                  title: Text(
                                    notif.mensaje,
                                    style: textTheme.bodyLarge?.copyWith(
                                      fontWeight: notif.leida ? FontWeight.normal : FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Hoy a las $timeStr',
                                    style: textTheme.labelLarge,
                                  ),
                                  trailing: !notif.leida
                                      ? Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: AppTheme.primaryTeal,
                                            shape: BoxShape.circle,
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
      ),
    );
  }
}

import 'dart:convert';
import 'api_client.dart';
import '../models/notification.dart';

class NotificationsService {
  final ApiClient _apiClient = ApiClient();

  // Obtener notificaciones del tutor (paginadas)
  Future<Map<String, dynamic>> getNotifications({String? tipo, bool? leida, int limit = 50, int offset = 0}) async {
    final queryParams = StringBuffer();
    queryParams.write('?limit=$limit&offset=$offset');
    if (tipo != null) queryParams.write('&tipo=$tipo');
    if (leida != null) queryParams.write('&leida=$leida');

    final response = await _apiClient.get('/notifications${queryParams.toString()}');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final list = data['notifications'] as List? ?? [];
      final notifications = list.map((i) => AppNotification.fromJson(i as Map<String, dynamic>)).toList();
      return {
        'notifications': notifications,
        'total': data['total'] as int? ?? 0,
        'unreadCount': data['unreadCount'] as int? ?? 0,
      };
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Error al obtener notificaciones');
    }
  }

  // Obtener contador de no leídas
  Future<int> getUnreadCount() async {
    final response = await _apiClient.get('/notifications/unread/count');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['count'] as int? ?? 0;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Error al obtener conteo de no leídas');
    }
  }

  // Marcar específicas como leídas
  Future<void> markAsRead(List<int> notificationIds) async {
    final response = await _apiClient.post('/notifications/mark-read', body: {
      'notificationIds': notificationIds,
    });
    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Error al marcar notificaciones como leídas');
    }
  }

  // Marcar todas como leídas
  Future<void> markAllAsRead() async {
    final response = await _apiClient.post('/notifications/mark-all-read');
    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Error al marcar todas las notificaciones como leídas');
    }
  }

  // Eliminar una notificación
  Future<void> eliminarNotificacion(int id) async {
    final response = await _apiClient.delete('/notifications/$id');
    if (response.statusCode != 200 && response.statusCode != 204) {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Error al eliminar la notificación');
    }
  }
}

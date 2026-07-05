import 'dart:convert';
import 'api_client.dart';
import '../models/zona_segura.dart';

class ZonasService {
  final ApiClient _apiClient = ApiClient();

  // Obtener todas las zonas seguras del tutor actual
  Future<List<ZonaSegura>> getZonas() async {
    final response = await _apiClient.get('/zonas-seguras');
    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List;
      return list.map((i) => ZonaSegura.fromJson(i as Map<String, dynamic>)).toList();
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Error al obtener las zonas seguras');
    }
  }

  // Crear una nueva zona segura
  Future<ZonaSegura> crearZona(ZonaSegura zona) async {
    final body = zona.toJson();
    body.remove('id');
    body.remove('fechaCreacion');

    final response = await _apiClient.post('/zonas-seguras', body: body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return ZonaSegura.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Error al crear la zona segura');
    }
  }

  // Actualizar una zona segura existente
  Future<ZonaSegura> actualizarZona(int id, ZonaSegura zona) async {
    final body = zona.toJson();
    body.remove('id');
    body.remove('fechaCreacion');

    final response = await _apiClient.patch('/zonas-seguras/$id', body: body);
    if (response.statusCode == 200) {
      return ZonaSegura.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Error al actualizar la zona segura');
    }
  }

  // Eliminar una zona segura
  Future<void> eliminarZona(int id) async {
    final response = await _apiClient.delete('/zonas-seguras/$id');
    if (response.statusCode != 200 && response.statusCode != 204) {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Error al eliminar la zona segura');
    }
  }
}

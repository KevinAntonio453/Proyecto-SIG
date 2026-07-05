import 'dart:convert';
import 'api_client.dart';
import '../models/hijo.dart';

class HijosService {
  final ApiClient _apiClient = ApiClient();

  // Obtener los hijos asociados al tutor actual
  Future<List<Hijo>> getMisHijos() async {
    final response = await _apiClient.get('/tutores/me/hijos');
    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List;
      return list.map((i) => Hijo.fromJson(i as Map<String, dynamic>)).toList();
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Error al obtener los hijos');
    }
  }

  // Registrar un nuevo hijo por parte de un tutor
  Future<Hijo> registrarHijo(String nombre, {String? apellido, String? telefono}) async {
    final response = await _apiClient.post('/tutores/me/hijos', body: {
      'nombre': nombre,
      if (apellido != null) 'apellido': apellido,
      if (telefono != null) 'telefono': telefono,
    });

    if (response.statusCode == 200 || response.statusCode == 201) {
      return Hijo.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Error al registrar el hijo');
    }
  }

  // Regenerar el código de vinculación
  Future<String> regenerarCodigo(int hijoId) async {
    final response = await _apiClient.post('/hijos/$hijoId/regenerar-codigo');
    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['codigoVinculacion'] as String;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Error al regenerar el código');
    }
  }

  // Enviar alerta SOS de pánico (Hijo)
  Future<void> enviarSOS(int hijoId) async {
    final response = await _apiClient.post('/hijos/$hijoId/sos');
    if (response.statusCode != 200 && response.statusCode != 201) {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Error al enviar alerta SOS');
    }
  }

  // Actualizar ubicación del hijo por HTTP
  Future<Hijo> actualizarUbicacion(int hijoId, double latitud, double longitud) async {
    final response = await _apiClient.patch('/hijos/$hijoId/location', body: {
      'latitud': latitud,
      'longitud': longitud,
    });

    if (response.statusCode == 200) {
      return Hijo.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Error al actualizar la ubicación');
    }
  }
}

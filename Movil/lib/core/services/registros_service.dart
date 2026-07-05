import 'dart:convert';
import 'api_client.dart';
import '../models/registro.dart';

class RegistrosService {
  final ApiClient _apiClient = ApiClient();

  // Obtener el historial de ubicaciones de un hijo en un rango de fechas
  Future<List<Registro>> getHistorial(int hijoId, {DateTime? inicio, DateTime? fin}) async {
    final queryParams = StringBuffer();
    if (inicio != null) queryParams.write('?fechaInicio=${inicio.toIso8601String()}');
    if (fin != null) {
      queryParams.write(queryParams.isEmpty ? '?' : '&');
      queryParams.write('fechaFin=${fin.toIso8601String()}');
    }

    final response = await _apiClient.get('/hijos/$hijoId/registros${queryParams.toString()}');
    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List;
      return list.map((i) => Registro.fromJson(i as Map<String, dynamic>)).toList();
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Error al obtener el historial de trayectorias');
    }
  }

  // Enviar un único registro de ubicación (para tracking continuo)
  Future<Registro> registrarUbicacion(Registro registro) async {
    final response = await _apiClient.post(
      '/hijos/${registro.hijoId}/registros',
      body: registro.toJson(),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return Registro.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Error al registrar la ubicación');
    }
  }

  // Sincronizar registros locales que se guardaron offline
  Future<void> sincronizarOffline(int hijoId, List<Registro> registros) async {
    if (registros.isEmpty) return;

    final body = {
      'registros': registros.map((r) {
        final data = r.toJson();
        data.remove('hijoId'); // No es necesario en el elemento del batch
        return data;
      }).toList(),
    };

    final response = await _apiClient.post('/hijos/$hijoId/registros/sync', body: body);
    if (response.statusCode != 200 && response.statusCode != 201) {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Error al sincronizar registros offline');
    }
  }
}

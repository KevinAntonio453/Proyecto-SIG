import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  // Callback global que se disparará en caso de recibir un 401
  static Function()? onUnauthorized;

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Map<String, String> _buildHeaders(String? token, Map<String, String>? customHeaders) {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    if (customHeaders != null) {
      headers.addAll(customHeaders);
    }
    return headers;
  }

  // Interceptor para verificar la validez del token en cada respuesta
  http.Response _checkResponse(http.Response response) {
    if (response.statusCode == 401) {
      final path = response.request?.url.path ?? '';
      print('🔌 [ApiClient] Detectado error 401 en ruta: $path');

      // No disparar el interceptor de deslogueo en endpoints de login/registro/vinculación
      if (path.contains('/auth/login') ||
          path.contains('/auth/login-codigo') ||
          path.contains('/auth/register') ||
          path.contains('/hijos/vincular') ||
          path.contains('/hijos/verificar-codigo')) {
        return response;
      }

      print('🔌 [ApiClient] Limpiando sesión local...');
      // 1. Limpiar almacenamiento local
      SharedPreferences.getInstance().then((prefs) {
        prefs.remove('access_token');
        prefs.remove('user_data');
        prefs.remove('user_type');
      });

      // 2. Disparar evento de deslogueo a la interfaz
      if (onUnauthorized != null) {
        onUnauthorized!();
      }
    }
    return response;
  }

  Future<http.Response> get(String path, {Map<String, String>? headers}) async {
    final token = await _getToken();
    final url = Uri.parse('${AppConstants.apiBaseUrl}$path');
    final response = await http.get(url, headers: _buildHeaders(token, headers));
    return _checkResponse(response);
  }

  Future<http.Response> post(String path, {dynamic body, Map<String, String>? headers}) async {
    final token = await _getToken();
    final url = Uri.parse('${AppConstants.apiBaseUrl}$path');
    final bodyStr = body != null ? jsonEncode(body) : null;
    final response = await http.post(url, body: bodyStr, headers: _buildHeaders(token, headers));
    return _checkResponse(response);
  }

  Future<http.Response> put(String path, {dynamic body, Map<String, String>? headers}) async {
    final token = await _getToken();
    final url = Uri.parse('${AppConstants.apiBaseUrl}$path');
    final bodyStr = body != null ? jsonEncode(body) : null;
    final response = await http.put(url, body: bodyStr, headers: _buildHeaders(token, headers));
    return _checkResponse(response);
  }

  Future<http.Response> patch(String path, {dynamic body, Map<String, String>? headers}) async {
    final token = await _getToken();
    final url = Uri.parse('${AppConstants.apiBaseUrl}$path');
    final bodyStr = body != null ? jsonEncode(body) : null;
    final response = await http.patch(url, body: bodyStr, headers: _buildHeaders(token, headers));
    return _checkResponse(response);
  }

  Future<http.Response> delete(String path, {dynamic body, Map<String, String>? headers}) async {
    final token = await _getToken();
    final url = Uri.parse('${AppConstants.apiBaseUrl}$path');
    final bodyStr = body != null ? jsonEncode(body) : null;
    final response = await http.delete(url, body: bodyStr, headers: _buildHeaders(token, headers));
    return _checkResponse(response);
  }
}

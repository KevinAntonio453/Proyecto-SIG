import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

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

  Future<http.Response> get(String path, {Map<String, String>? headers}) async {
    final token = await _getToken();
    final url = Uri.parse('${AppConstants.apiBaseUrl}$path');
    return http.get(url, headers: _buildHeaders(token, headers));
  }

  Future<http.Response> post(String path, {dynamic body, Map<String, String>? headers}) async {
    final token = await _getToken();
    final url = Uri.parse('${AppConstants.apiBaseUrl}$path');
    final bodyStr = body != null ? jsonEncode(body) : null;
    return http.post(url, body: bodyStr, headers: _buildHeaders(token, headers));
  }

  Future<http.Response> put(String path, {dynamic body, Map<String, String>? headers}) async {
    final token = await _getToken();
    final url = Uri.parse('${AppConstants.apiBaseUrl}$path');
    final bodyStr = body != null ? jsonEncode(body) : null;
    return http.put(url, body: bodyStr, headers: _buildHeaders(token, headers));
  }

  Future<http.Response> patch(String path, {dynamic body, Map<String, String>? headers}) async {
    final token = await _getToken();
    final url = Uri.parse('${AppConstants.apiBaseUrl}$path');
    final bodyStr = body != null ? jsonEncode(body) : null;
    return http.patch(url, body: bodyStr, headers: _buildHeaders(token, headers));
  }

  Future<http.Response> delete(String path, {dynamic body, Map<String, String>? headers}) async {
    final token = await _getToken();
    final url = Uri.parse('${AppConstants.apiBaseUrl}$path');
    final bodyStr = body != null ? jsonEncode(body) : null;
    return http.delete(url, body: bodyStr, headers: _buildHeaders(token, headers));
  }
}

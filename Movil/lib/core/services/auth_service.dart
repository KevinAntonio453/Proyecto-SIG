import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import '../models/user.dart';

class AuthService {
  final ApiClient _apiClient = ApiClient();

  // Guarda la sesión en preferencias locales
  Future<void> _saveSession(String token, Map<String, dynamic> userJson) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', token);
    await prefs.setString('user_data', jsonEncode(userJson));
    await prefs.setString('user_type', (userJson['type'] ?? userJson['tipo'] ?? 'tutor') as String);
  }

  // Cargar usuario autenticado actual desde el almacenamiento local
  Future<User?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString('user_data');
    if (userData == null) return null;
    return User.fromJson(jsonDecode(userData) as Map<String, dynamic>);
  }

  // Cargar tipo de usuario actual ('tutor' o 'hijo')
  Future<String?> getUserType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_type');
  }

  // Login normal (Tutores)
  Future<User> login(String email, String password) async {
    final response = await _apiClient.post('/auth/login', body: {
      'email': email,
      'password': password,
    });

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final token = data['access_token'] as String;
      final userJson = data['user'] as Map<String, dynamic>;
      
      await _saveSession(token, userJson);
      return User.fromJson(userJson);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Error al iniciar sesión');
    }
  }

  // Registro inicial (Tutores)
  Future<User> register(String nombre, String email, String password) async {
    final response = await _apiClient.post('/auth/register', body: {
      'nombre': nombre,
      'email': email,
      'password': password,
      'tipo': 'tutor',
    });

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final token = data['access_token'] as String;
      final userJson = data['user'] as Map<String, dynamic>;

      await _saveSession(token, userJson);
      return User.fromJson(userJson);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Error al registrar tutor');
    }
  }

  // Iniciar sesión con código de vinculación (Hijos)
  Future<User> loginConCodigo(String codigo) async {
    final response = await _apiClient.post('/auth/login-codigo', body: {
      'codigo': codigo.toUpperCase(),
    });

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final token = data['access_token'] as String;
      final userJson = data['user'] as Map<String, dynamic>;

      await _saveSession(token, userJson);
      return User.fromJson(userJson);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Código inválido o ya utilizado');
    }
  }

  // Verificar código de vinculación (Público)
  Future<Map<String, dynamic>> verificarCodigo(String codigo) async {
    final response = await _apiClient.get('/hijos/verificar-codigo/${codigo.toUpperCase()}');
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Código inválido');
    }
  }

  // Vincular y configurar datos del hijo (Público)
  Future<User> vincularHijo(String codigo, String email, String password) async {
    final response = await _apiClient.post('/hijos/vincular', body: {
      'codigo': codigo.toUpperCase(),
      'email': email,
      'password': password,
    });

    if (response.statusCode == 200 || response.statusCode == 201) {
      // Después de vincular, iniciamos sesión automáticamente con las nuevas credenciales
      return login(email, password);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Error al vincular el dispositivo');
    }
  }

  // Actualizar token FCM
  Future<void> updateFcmToken(String fcmToken) async {
    final response = await _apiClient.patch('/users/fcm-token', body: {
      'fcmToken': fcmToken,
    });
    if (response.statusCode != 200) {
      print('Advertencia: No se pudo registrar el token FCM en el servidor');
    }
  }

  // Cerrar sesión
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('user_data');
    await prefs.remove('user_type');
  }

  /// Verifica si el JWT almacenado sigue siendo válido (no expirado).
  /// Decodifica el payload del token localmente sin hacer llamadas de red.
  Future<bool> isTokenValid() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) return false;

    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;

      // Decodificar el payload (segunda parte del JWT)
      String payload = parts[1];
      // Agregar padding base64 si es necesario
      switch (payload.length % 4) {
        case 2:
          payload += '==';
          break;
        case 3:
          payload += '=';
          break;
      }
      final decoded = utf8.decode(base64Url.decode(payload));
      final Map<String, dynamic> data = jsonDecode(decoded) as Map<String, dynamic>;

      // Verificar expiración
      final exp = data['exp'] as int?;
      if (exp == null) return false;

      final expirationDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      // Considerar inválido si expira en menos de 30 segundos
      return DateTime.now().isBefore(expirationDate.subtract(const Duration(seconds: 30)));
    } catch (e) {
      print('⚠️ [AuthService] Error validando token JWT: $e');
      return false;
    }
  }
}

import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? _socket;
  bool _isConnected = false;

  bool get isConnected => _isConnected;
  IO.Socket? get socket => _socket;

  // Listas de callbacks para notificar a la interfaz de usuario en tiempo real
  final List<Function(Map<String, dynamic>)> _onLocationUpdatedCallbacks = [];
  final List<Function(Map<String, dynamic>)> _onStatusChangedCallbacks = [];
  final List<Function(Map<String, dynamic>)> _onPanicAlertCallbacks = [];
  final List<Function(Map<String, dynamic>)> _onLocationRequestedCallbacks = [];

  // Inicializar y conectar el socket
  Future<void> connect() async {
    if (_socket != null && _socket!.connected) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    
    if (token == null) {
      print('Socket: No se pudo conectar porque no hay token JWT guardado.');
      return;
    }

    _socket = IO.io(AppConstants.wsUrl, IO.OptionBuilder()
      .setTransports(['websocket', 'polling'])
      .setAuth({'token': token})
      .setQuery({'token': token, 'device': 'Mobile-App'})
      .enableAutoConnect()
      .build()
    );

    _socket!.onConnect((_) {
      _isConnected = true;
      print('🔌 Socket: Conexión establecida con éxito.');
    });

    _socket!.onDisconnect((_) {
      _isConnected = false;
      print('🔌 Socket: Desconectado del servidor.');
    });

    _socket!.onConnectError((err) {
      _isConnected = false;
      print('🔌 Socket error de conexión: $err');
    });

    // Escuchar eventos en tiempo real enviados desde el backend
    _socket!.on('locationUpdated', (data) {
      print('🔌 Socket [locationUpdated]: $data');
      for (var callback in _onLocationUpdatedCallbacks) {
        callback(data as Map<String, dynamic>);
      }
    });

    _socket!.on('childStatusChanged', (data) {
      print('🔌 Socket [childStatusChanged]: $data');
      for (var callback in _onStatusChangedCallbacks) {
        callback(data as Map<String, dynamic>);
      }
    });

    _socket!.on('panicAlert', (data) {
      print('🔌 Socket [panicAlert]: $data');
      for (var callback in _onPanicAlertCallbacks) {
        callback(data as Map<String, dynamic>);
      }
    });

    _socket!.on('locationRequested', (data) {
      print('🔌 Socket [locationRequested]: $data');
      for (var callback in _onLocationRequestedCallbacks) {
        callback(data as Map<String, dynamic>);
      }
    });
  }

  // --- MÉTODOS PARA EL TUTOR ---

  // Unirse al canal de un hijo para recibir sus eventos en tiempo real
  void suscribirseAHijo(int hijoId) {
    if (_socket == null || !_socket!.connected) return;
    _socket!.emit('joinChildRoom', {'childId': hijoId.toString()});
    print('suscribirseAHijo enviado para ID: $hijoId');
  }

  // Salir del canal de un hijo
  void desuscribirseDeHijo(int hijoId) {
    if (_socket == null || !_socket!.connected) return;
    _socket!.emit('leaveChildRoom', {'childId': hijoId.toString()});
    print('desuscribirseDeHijo enviado para ID: $hijoId');
  }

  // Solicitar que un hijo envíe su ubicación en este instante
  void solicitarUbicacionHijo(int hijoId) {
    if (_socket == null || !_socket!.connected) return;
    _socket!.emit('requestLocation', {'childId': hijoId.toString()});
  }

  // --- MÉTODOS PARA EL HIJO ---

  // Enviar ubicación en tiempo real (Hijo)
  void enviarUbicacion(double lat, double lng, {double battery = 100.0, String status = 'active'}) {
    if (_socket == null || !_socket!.connected) return;
    _socket!.emit('updateLocation', {
      'lat': lat,
      'lng': lng,
      'battery': battery,
      'status': status,
      'device': 'Android/iOS Mobile'
    });
  }

  // Notificar que está activo (Hijo)
  void marcarOnline() {
    if (_socket == null || !_socket!.connected) return;
    _socket!.emit('childOnline');
  }

  // Notificar que se desconecta (Hijo)
  void marcarOffline() {
    if (_socket == null || !_socket!.connected) return;
    _socket!.emit('childOffline');
  }

  // Emitir alerta de pánico SOS por WebSocket (Hijo)
  void emitirAlertaPanic(double lat, double lng) {
    if (_socket == null || !_socket!.connected) return;
    _socket!.emit('panicAlert', {
      'lat': lat,
      'lng': lng,
      'timestamp': DateTime.now().toIso8601String()
    });
  }

  // --- CONTROL DE CALLBACKS ---

  void registerLocationCallback(Function(Map<String, dynamic>) cb) => _onLocationUpdatedCallbacks.add(cb);
  void unregisterLocationCallback(Function(Map<String, dynamic>) cb) => _onLocationUpdatedCallbacks.remove(cb);

  void registerStatusCallback(Function(Map<String, dynamic>) cb) => _onStatusChangedCallbacks.add(cb);
  void unregisterStatusCallback(Function(Map<String, dynamic>) cb) => _onStatusChangedCallbacks.remove(cb);

  void registerPanicCallback(Function(Map<String, dynamic>) cb) => _onPanicAlertCallbacks.add(cb);
  void unregisterPanicCallback(Function(Map<String, dynamic>) cb) => _onPanicAlertCallbacks.remove(cb);

  void registerLocationRequestCallback(Function(Map<String, dynamic>) cb) => _onLocationRequestedCallbacks.add(cb);
  void unregisterLocationRequestCallback(Function(Map<String, dynamic>) cb) => _onLocationRequestedCallbacks.remove(cb);

  // Cerrar conexión
  void disconnect() {
    if (_socket != null) {
      _socket!.disconnect();
      _socket = null;
      _isConnected = false;
    }
  }
}

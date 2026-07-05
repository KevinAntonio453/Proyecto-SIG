import 'user.dart';

class Hijo extends User {
  final String? apellido;
  final String? telefono;
  final double? latitud;
  final double? longitud;
  final DateTime? ultimaConexion;
  final String? codigoVinculacion;
  final bool vinculado;
  final String estadoZona; // 'DENTRO' o 'FUERA'
  final int? zonaActualId;

  Hijo({
    required super.id,
    required super.nombre,
    super.email,
    required super.tipo,
    super.fcmToken,
    this.apellido,
    this.telefono,
    this.latitud,
    this.longitud,
    this.ultimaConexion,
    this.codigoVinculacion,
    required this.vinculado,
    required this.estadoZona,
    this.zonaActualId,
  });

  factory Hijo.fromJson(Map<String, dynamic> json) {
    return Hijo(
      id: json['id'] as int,
      nombre: json['nombre'] as String,
      email: json['email'] as String?,
      tipo: json['type'] ?? json['tipo'] ?? 'hijo',
      fcmToken: json['fcmToken'] as String?,
      apellido: json['apellido'] as String?,
      telefono: json['telefono'] as String?,
      latitud: json['latitud'] != null ? (json['latitud'] as num).toDouble() : null,
      longitud: json['longitud'] != null ? (json['longitud'] as num).toDouble() : null,
      ultimaConexion: json['ultimaconexion'] != null 
          ? DateTime.parse(json['ultimaconexion'] as String) 
          : null,
      codigoVinculacion: json['codigoVinculacion'] as String?,
      vinculado: json['vinculado'] as bool? ?? false,
      estadoZona: json['estadoZona'] as String? ?? 'FUERA',
      zonaActualId: json['zonaActualId'] as int?,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final data = super.toJson();
    data.addAll({
      'apellido': apellido,
      'telefono': telefono,
      'latitud': latitud,
      'longitud': longitud,
      'ultimaconexion': ultimaConexion?.toIso8601String(),
      'codigoVinculacion': codigoVinculacion,
      'vinculado': vinculado,
      'estadoZona': estadoZona,
      'zonaActualId': zonaActualId,
    });
    return data;
  }
}

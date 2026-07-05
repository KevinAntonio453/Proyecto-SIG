class AppNotification {
  final int id;
  final String mensaje;
  final String tipo; // 'zone_entry', 'zone_exit', 'sos_panico', 'info'
  final bool leida;
  final int tutorId;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.mensaje,
    required this.tipo,
    required this.leida,
    required this.tutorId,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as int,
      mensaje: json['mensaje'] as String,
      tipo: json['tipo'] as String? ?? 'info',
      leida: json['leida'] as bool? ?? false,
      tutorId: json['tutorId'] ?? json['tutor_id'] as int,
      createdAt: DateTime.parse(json['createdAt'] ?? json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'mensaje': mensaje,
      'tipo': tipo,
      'leida': leida,
      'tutor_id': tutorId,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

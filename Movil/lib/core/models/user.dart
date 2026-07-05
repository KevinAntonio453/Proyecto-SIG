class User {
  final int id;
  final String nombre;
  final String? email;
  final String tipo; // 'tutor' o 'hijo'
  final String? fcmToken;

  User({
    required this.id,
    required this.nombre,
    this.email,
    required this.tipo,
    this.fcmToken,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      nombre: json['nombre'] as String,
      email: json['email'] as String?,
      tipo: json['type'] ?? json['tipo'] ?? 'tutor',
      fcmToken: json['fcmToken'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'email': email,
      'type': tipo,
      'fcmToken': fcmToken,
    };
  }
}

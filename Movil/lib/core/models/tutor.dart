import 'user.dart';
import 'hijo.dart';

class Tutor extends User {
  final List<Hijo> hijos;

  Tutor({
    required super.id,
    required super.nombre,
    super.email,
    required super.tipo,
    super.fcmToken,
    required this.hijos,
  });

  factory Tutor.fromJson(Map<String, dynamic> json) {
    var list = json['hijos'] as List? ?? [];
    List<Hijo> hijosList = list.map((i) => Hijo.fromJson(i as Map<String, dynamic>)).toList();

    return Tutor(
      id: json['id'] as int,
      nombre: json['nombre'] as String,
      email: json['email'] as String?,
      tipo: json['type'] ?? json['tipo'] ?? 'tutor',
      fcmToken: json['fcmToken'] as String?,
      hijos: hijosList,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final data = super.toJson();
    data['hijos'] = hijos.map((h) => h.toJson()).toList();
    return data;
  }
}

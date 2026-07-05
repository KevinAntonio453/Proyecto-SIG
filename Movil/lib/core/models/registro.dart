class Registro {
  final int? id;
  final DateTime hora;
  final double latitud;
  final double longitud;
  final int hijoId;
  final bool fueOffline;
  final DateTime? creadoEn;

  Registro({
    this.id,
    required this.hora,
    required this.latitud,
    required this.longitud,
    required this.hijoId,
    required this.fueOffline,
    this.creadoEn,
  });

  factory Registro.fromJson(Map<String, dynamic> json) {
    return Registro(
      id: json['id'] as int?,
      hora: DateTime.parse(json['hora'] as String),
      latitud: (json['latitud'] as num).toDouble(),
      longitud: (json['longitud'] as num).toDouble(),
      hijoId: json['hijoId'] as int,
      fueOffline: json['fueOffline'] as bool? ?? false,
      creadoEn: json['creadoEn'] != null ? DateTime.parse(json['creadoEn'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'hora': hora.toIso8601String(),
      'latitud': latitud,
      'longitud': longitud,
      'hijoId': hijoId,
      'fueOffline': fueOffline,
      if (creadoEn != null) 'creadoEn': creadoEn!.toIso8601String(),
    };
  }
}

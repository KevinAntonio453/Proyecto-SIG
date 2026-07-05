import 'package:latlong2/latlong.dart';
import 'hijo.dart';

class ZonaSegura {
  final int id;
  final String nombre;
  final String? descripcion;
  final List<LatLng> puntos; // Convertido desde coordenadas GeoJSON [[[lng, lat]]]
  final List<Hijo> hijos;
  final DateTime fechaCreacion;

  ZonaSegura({
    required this.id,
    required this.nombre,
    this.descripcion,
    required this.puntos,
    required this.hijos,
    required this.fechaCreacion,
  });

  factory ZonaSegura.fromJson(Map<String, dynamic> json) {
    List<LatLng> pointsList = [];
    if (json['poligono'] != null && json['poligono']['coordinates'] != null) {
      try {
        var outerRing = json['poligono']['coordinates'][0] as List;
        for (var coord in outerRing) {
          double lng = (coord[0] as num).toDouble();
          double lat = (coord[1] as num).toDouble();
          pointsList.add(LatLng(lat, lng));
        }
      } catch (e) {
        print('Error parseando coordenadas del polígono: $e');
      }
    }

    var list = json['hijos'] as List? ?? [];
    List<Hijo> hijosList = list.map((i) => Hijo.fromJson(i as Map<String, dynamic>)).toList();

    return ZonaSegura(
      id: json['id'] as int,
      nombre: json['nombre'] as String,
      descripcion: json['descripcion'] as String?,
      puntos: pointsList,
      hijos: hijosList,
      fechaCreacion: DateTime.parse(json['fechaCreacion'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'descripcion': descripcion,
      'poligono': {
        'type': 'Polygon',
        'coordinates': [
          puntos.map((p) => [p.longitude, p.latitude]).toList()
        ]
      },
      'hijosIds': hijos.map((h) => h.id).toList(),
      'fechaCreacion': fechaCreacion.toIso8601String(),
    };
  }
}

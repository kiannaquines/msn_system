import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:mns_rider/src/config.dart';

class RoutePlan {
  const RoutePlan({
    required this.points,
    required this.instructions,
    required this.distanceKm,
    required this.durationMinutes,
  });

  final List<LatLng> points;
  final List<String> instructions;
  final double distanceKm;
  final int durationMinutes;
}

class MapboxRouteService {
  const MapboxRouteService();

  Future<RoutePlan?> loadRoute(LatLng pickup, LatLng destination) async {
    if (AppConfig.mapboxPublicToken.isEmpty) return null;
    final coordinates = '${pickup.longitude},${pickup.latitude};'
        '${destination.longitude},${destination.latitude}';
    final uri = Uri.https(
      'api.mapbox.com',
      '/directions/v5/mapbox/driving-traffic/$coordinates',
      {
        'access_token': AppConfig.mapboxPublicToken,
        'geometries': 'geojson',
        'overview': 'full',
        'steps': 'true',
      },
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) return null;
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final routes = data['routes'] as List<dynamic>? ?? const [];
    if (routes.isEmpty) return null;
    final route = routes.first as Map<String, dynamic>;
    final geometry = route['geometry'] as Map<String, dynamic>;
    final points = (geometry['coordinates'] as List<dynamic>)
        .map((coordinate) {
          final values = coordinate as List<dynamic>;
          return LatLng(
            (values[1] as num).toDouble(),
            (values[0] as num).toDouble(),
          );
        })
        .toList(growable: false);
    final instructions = <String>[];
    for (final legValue in route['legs'] as List<dynamic>? ?? const []) {
      final leg = legValue as Map<String, dynamic>;
      for (final stepValue in leg['steps'] as List<dynamic>? ?? const []) {
        final step = stepValue as Map<String, dynamic>;
        final maneuver = step['maneuver'] as Map<String, dynamic>?;
        final instruction = maneuver?['instruction'] as String?;
        if (instruction != null && instruction.isNotEmpty) {
          instructions.add(instruction);
        }
      }
    }
    return RoutePlan(
      points: points,
      instructions: instructions,
      distanceKm: (route['distance'] as num).toDouble() / 1000,
      durationMinutes: ((route['duration'] as num).toDouble() / 60).ceil(),
    );
  }
}

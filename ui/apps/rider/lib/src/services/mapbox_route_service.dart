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
    final coordinates = '${pickup.longitude},${pickup.latitude};${destination.longitude},${destination.latitude}';

    // 1. Query Mapbox Directions API with alternatives=true to find shortest / fastest route
    if (AppConfig.mapboxPublicToken.isNotEmpty) {
      try {
        final uri = Uri.https(
          'api.mapbox.com',
          '/directions/v5/mapbox/driving-traffic/$coordinates',
          {
            'access_token': AppConfig.mapboxPublicToken,
            'geometries': 'geojson',
            'overview': 'full',
            'steps': 'true',
            'alternatives': 'true',
          },
        );
        final response = await http.get(uri).timeout(const Duration(seconds: 6));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final routes = data['routes'] as List<dynamic>? ?? const [];
          if (routes.isNotEmpty) {
            // Find the route with the shortest distance among alternatives
            var bestRoute = routes.first as Map<String, dynamic>;
            var minDistance = (bestRoute['distance'] as num).toDouble();

            for (final r in routes) {
              final routeMap = r as Map<String, dynamic>;
              final dist = (routeMap['distance'] as num).toDouble();
              if (dist < minDistance) {
                minDistance = dist;
                bestRoute = routeMap;
              }
            }

            final geometry = bestRoute['geometry'] as Map<String, dynamic>;
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
            for (final legValue in bestRoute['legs'] as List<dynamic>? ?? const []) {
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
              distanceKm: minDistance / 1000,
              durationMinutes: ((bestRoute['duration'] as num).toDouble() / 60).ceil(),
            );
          }
        }
      } catch (_) {}
    }

    // 2. OpenStreetMap / OSRM optimized routing fallback
    try {
      final osrmUri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/$coordinates?overview=full&geometries=geojson&steps=true&alternatives=true',
      );
      final response = await http.get(osrmUri).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final routes = data['routes'] as List<dynamic>? ?? const [];
        if (routes.isNotEmpty) {
          // Select shortest route
          var bestRoute = routes.first as Map<String, dynamic>;
          var minDistance = (bestRoute['distance'] as num).toDouble();

          for (final r in routes) {
            final routeMap = r as Map<String, dynamic>;
            final dist = (routeMap['distance'] as num).toDouble();
            if (dist < minDistance) {
              minDistance = dist;
              bestRoute = routeMap;
            }
          }

          final geometry = bestRoute['geometry'] as Map<String, dynamic>;
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
          for (final legValue in bestRoute['legs'] as List<dynamic>? ?? const []) {
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
            distanceKm: minDistance / 1000,
            durationMinutes: ((bestRoute['duration'] as num).toDouble() / 60).ceil(),
          );
        }
      }
    } catch (_) {}

    return null;
  }
}

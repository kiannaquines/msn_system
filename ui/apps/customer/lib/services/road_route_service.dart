import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class CustomerRoadRouteService {
  const CustomerRoadRouteService();

  static final Map<String, List<LatLng>> _cache = {};

  Future<List<LatLng>> getRoutePoints({
    required LatLng origin,
    required LatLng destination,
    LatLng? waypoint,
    String? mapboxToken,
  }) async {
    final key = waypoint == null
        ? '${origin.latitude.toStringAsFixed(4)},${origin.longitude.toStringAsFixed(4)}-${destination.latitude.toStringAsFixed(4)},${destination.longitude.toStringAsFixed(4)}'
        : '${origin.latitude.toStringAsFixed(4)},${origin.longitude.toStringAsFixed(4)}-${waypoint.latitude.toStringAsFixed(4)},${waypoint.longitude.toStringAsFixed(4)}-${destination.latitude.toStringAsFixed(4)},${destination.longitude.toStringAsFixed(4)}';

    if (_cache.containsKey(key) && _cache[key]!.isNotEmpty) {
      return _cache[key]!;
    }

    final coordinates = waypoint == null
        ? '${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}'
        : '${origin.longitude},${origin.latitude};${waypoint.longitude},${waypoint.latitude};${destination.longitude},${destination.latitude}';

    // 1. Try Mapbox Directions API with alternatives=true to find shortest route
    if (mapboxToken != null && mapboxToken.isNotEmpty) {
      try {
        final uri = Uri.https(
          'api.mapbox.com',
          '/directions/v5/mapbox/driving-traffic/$coordinates',
          {
            'access_token': mapboxToken,
            'geometries': 'geojson',
            'overview': 'full',
            'alternatives': 'true',
          },
        );
        final response = await http.get(uri).timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final routes = data['routes'] as List<dynamic>? ?? const [];
          if (routes.isNotEmpty) {
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
                .map((coord) {
                  final values = coord as List<dynamic>;
                  return LatLng(
                    (values[1] as num).toDouble(),
                    (values[0] as num).toDouble(),
                  );
                })
                .toList();
            if (points.isNotEmpty) {
              _cache[key] = points;
              return points;
            }
          }
        }
      } catch (_) {}
    }

    // 2. Try OpenStreetMap / OSRM routing API fallback
    try {
      final osrmUri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/$coordinates?overview=full&geometries=geojson&alternatives=true',
      );
      final response = await http.get(osrmUri).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final routes = data['routes'] as List<dynamic>? ?? const [];
        if (routes.isNotEmpty) {
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
              .map((coord) {
                final values = coord as List<dynamic>;
                return LatLng(
                  (values[1] as num).toDouble(),
                  (values[0] as num).toDouble(),
                );
              })
              .toList();
          if (points.isNotEmpty) {
            _cache[key] = points;
            return points;
          }
        }
      }
    } catch (_) {}

    final fallback = waypoint == null ? [origin, destination] : [origin, waypoint, destination];
    _cache[key] = fallback;
    return fallback;
  }
}

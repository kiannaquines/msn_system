import 'dart:convert';
import 'dart:io';

class ReverseGeocoder {
  static const String _mapboxToken = String.fromEnvironment('MAPBOX_PUBLIC_TOKEN');

  /// Reverse geocodes latitude and longitude into a clean Philippine street address.
  static Future<String?> getAddress(double latitude, double longitude) async {
    // 1. Try Mapbox Geocoding if token is provided
    if (_mapboxToken.isNotEmpty) {
      try {
        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 4);
        final uri = Uri.parse(
          'https://api.mapbox.com/geocoding/v5/mapbox.places/$longitude,$latitude.json'
          '?access_token=$_mapboxToken&country=PH&types=address,poi,neighborhood,locality,place',
        );
        final request = await client.getUrl(uri);
        final response = await request.close();
        if (response.statusCode == 200) {
          final responseBody = await response.transform(utf8.decoder).join();
          final data = jsonDecode(responseBody) as Map<String, dynamic>;
          final features = data['features'] as List<dynamic>?;
          if (features != null && features.isNotEmpty) {
            final first = features.first as Map<String, dynamic>;
            final placeName = first['place_name'] as String?;
            if (placeName != null && placeName.isNotEmpty) {
              return _cleanPhilippineAddress(placeName);
            }
          }
        }
      } catch (_) {
        // Fallthrough to OSM
      }
    }

    // 2. Fallback to OpenStreetMap Nominatim
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 4);
      client.userAgent = 'MnsDeliveryCustomerApp/1.0';
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$latitude&lon=$longitude&zoom=18&addressdetails=1',
      );
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final data = jsonDecode(responseBody) as Map<String, dynamic>;
        final displayName = data['display_name'] as String?;
        if (displayName != null && displayName.isNotEmpty) {
          return _cleanPhilippineAddress(displayName);
        }
      }
    } catch (_) {
      // Fallthrough
    }

    // 3. Fallback coordinate label
    return 'Location Pin (${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)})';
  }

  static String _cleanPhilippineAddress(String raw) {
    var cleaned = raw.replaceAll(', Philippines', '').replaceAll('Philippines', '').trim();
    if (cleaned.endsWith(',')) {
      cleaned = cleaned.substring(0, cleaned.length - 1).trim();
    }
    return cleaned;
  }
}

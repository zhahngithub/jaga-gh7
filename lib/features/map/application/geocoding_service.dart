import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// model buat nampung nama sama koordinat
class LocationResult {
  final String displayName;
  final LatLng coordinates;

  LocationResult({required this.displayName, required this.coordinates});
}

// state riverpod
class DestinationNotifier extends Notifier<LatLng?> {
  @override
  LatLng? build() => null;

  // fungsi update state
  void updateLocation(LatLng? newLocation) {
    state = newLocation;
  }
}

final destinationProvider = NotifierProvider<DestinationNotifier, LatLng?>(
  DestinationNotifier.new,
);

class GeocodingService {
  // api key akun gw
  static const String apiKey = 'pk.53befdbc81da2eae90473cb988cc9e57';

  // api call buat list
  static Future<List<LocationResult>> searchDestinations(String query) async {
    // cari max 5 result di indo
    final url = Uri.parse(
        'https://us1.locationiq.com/v1/search?key=$apiKey&q=$query&format=json&countrycodes=id&limit=5');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        
        // map data ke list
        return data.map((item) {
          final lat = double.parse(item['lat']);
          final lon = double.parse(item['lon']);
          
          return LocationResult(
            displayName: item['display_name'],
            coordinates: LatLng(lat, lon),
          );
        }).toList();
      }
    } catch (e) {
      // kalau fail
      return []; 
    }
    return [];
  }
}
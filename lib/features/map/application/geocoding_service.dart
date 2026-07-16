import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DestinationNotifier extends Notifier<LatLng?> {
  @override
  LatLng? build() => null;

  void updateLocation(LatLng? newLocation) {
    state = newLocation;
  }
}

final destinationProvider = NotifierProvider<DestinationNotifier, LatLng?>(
  DestinationNotifier.new,
);

class GeocodingService {
  // api key akun gw, males env
  static const String apiKey = 'pk.53befdbc81da2eae90473cb988cc9e57';

  // api call
  static Future<LatLng?> searchDestination(String query) async {
    // specific manggil indonesia
    final url = Uri.parse(
        'https://us1.locationiq.com/v1/search?key=$apiKey&q=$query&format=json&countrycodes=id&limit=1');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        
        if (data.isNotEmpty) {
          // parse ke decimal
          final lat = double.parse(data[0]['lat']);
          final lon = double.parse(data[0]['lon']);
          return LatLng(lat, lon);
        }
      }
    } catch (e) {
      // kalau fail
      return null; 
    }
    return null;
  }
}
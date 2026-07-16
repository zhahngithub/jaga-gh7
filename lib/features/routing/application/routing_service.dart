import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// state buat nyimpen garis rute
class RouteNotifier extends Notifier<List<LatLng>> {
  @override
  List<LatLng> build() => [];

  // update rute di map
  void updateRoute(List<LatLng> newRoute) {
    state = newRoute;
  }

  // hapus rute
  void clearRoute() {
    state = [];
  }
}

// provider rute
final routeProvider = NotifierProvider<RouteNotifier, List<LatLng>>(
  RouteNotifier.new,
);

class RoutingService {
  // apikey openrouteservice, abis hackathon apus akun jangan lupa -riki
  static const String apiKey = 'eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6IjQ3ZDRmNzI4ZGU0YTQ1ZWVhNTc0YmZlZjgzNDE5MmQyIiwiaCI6Im11cm11cjY0In0=';

  // api call buat ambil rute mobil
  static Future<List<LatLng>> getRoute(LatLng start, LatLng end) async {
    // ors wajib format longitude,latitude
    final startCoords = '${start.longitude},${start.latitude}';
    final endCoords = '${end.longitude},${end.latitude}';
    
    final url = Uri.parse(
      'https://api.openrouteservice.org/v2/directions/driving-car?api_key=$apiKey&start=$startCoords&end=$endCoords'
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // ekstrak array koordinat dari geojson
        final List<dynamic> coordinates = data['features'][0]['geometry']['coordinates'];
        
        // map json balik ke latlng buat flutter map
        return coordinates.map((coord) {
          // coord[0] itu lon, coord[1] itu lat
          return LatLng(coord[1], coord[0]);
        }).toList();
      }
    } catch (e) {
      // kalau error return kosong
      return [];
    }
    return [];
  }
}
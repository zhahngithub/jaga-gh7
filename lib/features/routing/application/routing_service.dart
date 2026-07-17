import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../reports/data/models/report.dart';

// 1. Buat class buat nyimpen 2 rute sekaligus
class RouteState {
  final List<LatLng> mainRoute;
  final List<LatLng> safeRoute;

  RouteState({
    this.mainRoute = const [], 
    this.safeRoute = const []
  });
}

class RouteNotifier extends Notifier<RouteState> {
  @override
  RouteState build() => RouteState();

  // update state dengan rute utama dan (opsional) rute aman
  void updateRoutes({required List<LatLng> main, List<LatLng> safe = const []}) {
    state = RouteState(mainRoute: main, safeRoute: safe);
  }

  void clearRoutes() {
    state = RouteState();
  }
}

final routeProvider = NotifierProvider<RouteNotifier, RouteState>(
  RouteNotifier.new,
);

class RoutingService {
  // masukin api key ors lu di sini
  static const String apiKey = 'eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6IjQ3ZDRmNzI4ZGU0YTQ1ZWVhNTc0YmZlZjgzNDE5MmQyIiwiaCI6Im11cm11cjY0In0=';

  static Future<List<LatLng>> getRoute(
    LatLng start, 
    LatLng end, 
    {List<Report> hazards = const []}
  ) async {
    final url = Uri.parse('https://api.openrouteservice.org/v2/directions/driving-car/geojson');

    final Map<String, dynamic> body = {
      "coordinates": [
        [start.longitude, start.latitude],
        [end.longitude, end.latitude]
      ],
    };

    // kalau ada bahaya, kita bikin bounding box 100 meter buat dihindari
    if (hazards.isNotEmpty) {
      // 0.0009 derajat itu kurang lebih radius 100 meter
      const offset = 0.0009; 
      List<List<List<List<double>>>> avoidPolygons = [];

      for (var hazard in hazards) {
        final lat = hazard.location.latitude;
        final lon = hazard.location.longitude;

        avoidPolygons.add([
          [
            [lon - offset, lat - offset], 
            [lon + offset, lat - offset], 
            [lon + offset, lat + offset], 
            [lon - offset, lat + offset], 
            [lon - offset, lat - offset], 
          ]
        ]);
      }

      body["options"] = {
        "avoid_polygons": {
          "type": "MultiPolygon",
          "coordinates": avoidPolygons
        }
      };
    }

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': apiKey,
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json, application/geo+json, application/gpx+xml, img/png; charset=utf-8'
        },
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> coordinates = data['features'][0]['geometry']['coordinates'];
        
        return coordinates.map((coord) {
          return LatLng(coord[1], coord[0]);
        }).toList();
      } else {
        // INI PENTING: Print error dari ORS biar ketahuan kalau API nolak
        print('ORS API Error: ${response.statusCode}');
        print('Response body: ${response.body}');
        return [];
      }
    } catch (e) {
      print('Routing Network Error: $e');
      return [];
    }
    return [];
  }
}
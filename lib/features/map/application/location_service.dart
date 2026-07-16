import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

// riverpod provider buat state
final liveLocationProvider = StreamProvider<LatLng>((ref) async* {
  bool serviceEnabled;
  LocationPermission permission;

  // cek permission
  serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) throw Exception('Location services are disabled.');

  permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      throw Exception('Location permissions are denied');
    }
  }
  
  if (permission == LocationPermission.deniedForever) {
    throw Exception('Location permissions are permanently denied.');
  }

  // gps stream
  const locationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 5, // ganti aja mau berapa meter baru gerak
  );

  // map ke ui
  // kalau ga di screen auto ga di update
  yield* Geolocator.getPositionStream(locationSettings: locationSettings)
      .map((Position position) => LatLng(position.latitude, position.longitude));
});
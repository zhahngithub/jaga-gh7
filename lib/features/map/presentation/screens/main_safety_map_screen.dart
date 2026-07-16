import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../widgets/destination_search_bar.dart';

class MainSafetyMapScreen extends StatefulWidget {
  const MainSafetyMapScreen({super.key});

  @override
  State<MainSafetyMapScreen> createState() => _MainSafetyMapScreenState();
}

class _MainSafetyMapScreenState extends State<MainSafetyMapScreen> {
  // buat atur camera gerak
  final MapController _mapController = MapController();
  
  // live location
  LatLng? _currentPosition;

  // realtime stream
  StreamSubscription<Position>? _positionStreamSubscription;

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  // kalau lagi ga di screen dia ga update
  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  // permission, data
  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // tes location service
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return; // Location services are not enabled don't continue
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return; // permission denied
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      return; // Permissions are permanently denied
    } 

    // initial fetch location
    Position position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );

    if (!mounted) return;

    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
    });

    // tambahin delay biar ga langsung load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_currentPosition != null) {
        _mapController.move(_currentPosition!, 15.0);
      }
    });

    // live update buat 5 meter movement
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      if (!mounted) return;
      
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
      });
      
      // Note: We update the state to move the blue marker, but we DO NOT 
      // automatically move the camera here. Otherwise, the user could never 
      // pan around the map because the camera would constantly snap back to them!
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: LatLng(-6.1783, 106.6319), // fallback
              initialZoom: 13.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.yourname.jaga',
              ),
              if (_currentPosition != null) // marker current location
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentPosition!,
                      width: 50.0,
                      height: 50.0,
                      child: const Icon(
                        Icons.my_location,
                        color: Colors.blueAccent,
                        size: 40.0,
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // 2. Floating User Interface Controls
          const SafeArea(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                children: [
                  DestinationSearchBar(),
                  // Future team additions (e.g. transport mode toggles) go here smoothly
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_currentPosition != null) {
            _mapController.move(_currentPosition!, 15.0);
          }
        },
        backgroundColor: Colors.white,
        child: const Icon(Icons.my_location, color: Colors.blueAccent),
      ),
    );
  }
}
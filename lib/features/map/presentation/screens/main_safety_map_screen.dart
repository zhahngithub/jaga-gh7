import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../widgets/destination_search_bar.dart';

class MainSafetyMapScreen extends StatefulWidget {
  const MainSafetyMapScreen({super.key});

  @override
  State<MainSafetyMapScreen> createState() => _MainSafetyMapScreenState();
}

class _MainSafetyMapScreenState extends State<MainSafetyMapScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. The Underlying Map System
          FlutterMap(
            options: const MapOptions(
              initialCenter: LatLng(-6.1783, 106.6319),
              initialZoom: 13.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.yourname.jaga',
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
    );
  }
}
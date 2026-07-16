import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:jaga/features/map/presentation/widgets/safety_check_dialog.dart';
import 'package:latlong2/latlong.dart';
import '../widgets/destination_search_bar.dart';
import '../widgets/welcome_dialog.dart';

class MainSafetyMapScreen extends StatefulWidget {
  const MainSafetyMapScreen({super.key});

  @override
  State<MainSafetyMapScreen> createState() => _MainSafetyMapScreenState();
}

class _MainSafetyMapScreenState extends State<MainSafetyMapScreen> {
  @override
  void initState() {
    super.initState();
    
    // Wait for the UI to finish building, then show the pop-up
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showWelcomePopup();
    });
  }

  void _showWelcomePopup() {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevents closing by tapping outside the box
      builder: (BuildContext context) {
        // Render your reusable component here
        return const WelcomeDialog(username: "Ricky"); 
      },
    );
  }

  void _showSafetyCheckPopup(int distance) {
    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (BuildContext context) {
        return SafetyCheckDialog(distanceInMeters: distance);
      },
    );
  }

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
          SafeArea(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                children: [
                  DestinationSearchBar(),
                  // Future team additions (e.g. transport mode toggles) go here smoothly
                  // OTHER ADDITIONS
                  const SizedBox(height: 16), // Space before the button
                  
                  // 3. --- DEBUG BUTTON ---
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange, // Orange to mark it as a debug tool
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      // Pass a dummy distance to test the UI
                      _showSafetyCheckPopup(150); 
                    },
                    icon: const Icon(Icons.bug_report),
                    label: const Text("DEBUG: Test Danger Popup"),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
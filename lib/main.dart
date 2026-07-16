import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final firebaseApp = await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  debugPrint('Firebase berhasil diinisialisasi');
  debugPrint('Project ID: ${firebaseApp.options.projectId}');
  debugPrint('Firebase App ID: ${firebaseApp.options.appId}');
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MainSafetyMapScreen(),
    );
  }
}

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
          // 1. The Core Map Widget
          FlutterMap(
            options: const MapOptions(
              // Centered around Tangerang / Greater Jakarta
              initialCenter: LatLng(-6.1783, 106.6319),
              initialZoom: 13.0,
            ),
            children: [
              // 2. The Free OpenStreetMap Tile Layer
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.yourname.jaga',
              ),
            ],
          ),

          // 3. UI Overlay: Destination Search Bar Placeholder
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(27.0),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8.0,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: const Row(
                  children: [
                    Icon(Icons.search, color: Colors.grey),
                    SizedBox(width: 12),
                    Text(
                      'Search destination...',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
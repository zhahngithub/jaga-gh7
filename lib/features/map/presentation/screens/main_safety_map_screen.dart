import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:jaga/features/map/presentation/widgets/safety_check_dialog.dart';
import 'package:latlong2/latlong.dart';
import '../widgets/destination_search_bar.dart';
import '../../application/location_service.dart';
import '../../application/geocoding_service.dart';
import '../widgets/welcome_dialog.dart';

class MainSafetyMapScreen extends ConsumerStatefulWidget {
  const MainSafetyMapScreen({super.key});

  @override
  ConsumerState<MainSafetyMapScreen> createState() => _MainSafetyMapScreenState();
}

class _MainSafetyMapScreenState extends ConsumerState<MainSafetyMapScreen> {
  final MapController _mapController = MapController();
  bool _hasInitialCameraMoved = false;

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

  void _dismissSearch() {
    FocusScope.of(context).unfocus();
    ref.read(searchResultsVisibleProvider.notifier).hide();
  }

  @override
  Widget build(BuildContext context) {
    // pake provider
    final locationAsyncValue = ref.watch(liveLocationProvider);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(-6.1783, 106.6319), // fallback
              initialZoom: 13.0,
              onTap: (_, _) => _dismissSearch(),
              onPositionChanged: (_, hasGesture) {
                if (hasGesture) {
                  _dismissSearch();
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.yourname.jaga',
              ),
              
              // kalau ada data location, draw marker
              locationAsyncValue.when(
                data: (currentPosition) {
                  // Move camera on first load
                  if (!_hasInitialCameraMoved) {
                    _hasInitialCameraMoved = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _mapController.move(currentPosition, 15.0);
                    });
                  }

                  // 1. Check if the user has searched for a destination
                  final destinationPosition = ref.watch(destinationProvider);
                  
                  // 2. Build the list of markers
                  List<Marker> mapMarkers = [
                    // The Blue User Marker
                    Marker(
                      point: currentPosition,
                      width: 50.0,
                      height: 50.0,
                      child: const Icon(
                        Icons.my_location,
                        color: Colors.blueAccent,
                        size: 40.0,
                      ),
                    ),
                  ];

                  // 3. If a destination exists, add a Red Pin to the map!
                  if (destinationPosition != null) {
                    mapMarkers.add(
                      Marker(
                        point: destinationPosition,
                        width: 50.0,
                        height: 50.0,
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 40.0,
                        ),
                      ),
                    );
                    
                    // Optional: Automatically move the camera to see the new pin
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _mapController.move(destinationPosition, 15.0);
                    });
                  }
                  
                  return MarkerLayer(markers: mapMarkers);
                },
                loading: () => const SizedBox.shrink(),
                error: (error, stack) => const SizedBox.shrink(),
              ),
            ],
          ),

          SafeArea(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                children: [
                  DestinationSearchBar(),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // fokus ke marker
          final currentPosition = ref.read(liveLocationProvider).value;
          if (currentPosition != null) {
            _mapController.move(currentPosition, 15.0);
          }
        },
        backgroundColor: Colors.white,
        child: const Icon(Icons.my_location, color: Colors.blueAccent),
      ),
    );
  }
}

// class MainSafetyMapScreen extends StatefulWidget {
//   const MainSafetyMapScreen({super.key});

//   @override
//   State<MainSafetyMapScreen> createState() => _MainSafetyMapScreenState();
// }

// class _MainSafetyMapScreenState extends State<MainSafetyMapScreen> {
//   // buat atur camera gerak
//   final MapController _mapController = MapController();
  
//   // live location
//   LatLng? _currentPosition;

//   // realtime stream
//   StreamSubscription<Position>? _positionStreamSubscription;

//   @override
//   void initState() {
//     super.initState();
//     _determinePosition();
//   }

//   // kalau lagi ga di screen dia ga update
//   @override
//   void dispose() {
//     _positionStreamSubscription?.cancel();
//     super.dispose();
//   }

//   // permission, data
//   Future<void> _determinePosition() async {
//     bool serviceEnabled;
//     LocationPermission permission;

//     // tes location service
//     serviceEnabled = await Geolocator.isLocationServiceEnabled();
//     if (!serviceEnabled) {
//       return; // Location services are not enabled don't continue
//     }

//     permission = await Geolocator.checkPermission();
//     if (permission == LocationPermission.denied) {
//       permission = await Geolocator.requestPermission();
//       if (permission == LocationPermission.denied) {
//         return; // permission denied
//       }
//     }
    
//     if (permission == LocationPermission.deniedForever) {
//       return; // Permissions are permanently denied
//     } 

//     // initial fetch location
//     Position position = await Geolocator.getCurrentPosition(
//       locationSettings: const LocationSettings(
//         accuracy: LocationAccuracy.high,
//       ),
//     );

//     if (!mounted) return;

//     setState(() {
//       _currentPosition = LatLng(position.latitude, position.longitude);
//     });

//     // tambahin delay biar ga langsung load
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       if (_currentPosition != null) {
//         _mapController.move(_currentPosition!, 15.0);
//       }
//     });

//     // live update buat 5 meter movement
//     const locationSettings = LocationSettings(
//       accuracy: LocationAccuracy.high,
//       distanceFilter: 5,
//     );

//     _positionStreamSubscription = Geolocator.getPositionStream(
//       locationSettings: locationSettings,
//     ).listen((Position position) {
//       if (!mounted) return;
      
//       setState(() {
//         _currentPosition = LatLng(position.latitude, position.longitude);
//       });
      
//       // Note: We update the state to move the blue marker, but we DO NOT 
//       // automatically move the camera here. Otherwise, the user could never 
//       // pan around the map because the camera would constantly snap back to them!
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Stack(
//         children: [
//           FlutterMap(
//             mapController: _mapController,
//             options: const MapOptions(
//               initialCenter: LatLng(-6.1783, 106.6319), // fallback
//               initialZoom: 13.0,
//             ),
//             children: [
//               TileLayer(
//                 urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
//                 userAgentPackageName: 'com.yourname.jaga',
//               ),
//               if (_currentPosition != null) // marker current location
//                 MarkerLayer(
//                   markers: [
//                     Marker(
//                       point: _currentPosition!,
//                       width: 50.0,
//                       height: 50.0,
//                       child: const Icon(
//                         Icons.my_location,
//                         color: Colors.blueAccent,
//                         size: 40.0,
//                       ),
//                     ),
//                   ],
//                 ),
//             ],
//           ),

//           // 2. Floating User Interface Controls
//           const SafeArea(
//             child: Padding(
//               padding: EdgeInsets.all(16.0),
//               child: Column(
//                 children: [
//                   DestinationSearchBar(),
//                   // Future team additions (e.g. transport mode toggles) go here smoothly
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: () {
//           if (_currentPosition != null) {
//             _mapController.move(_currentPosition!, 15.0);
//           }
//         },
//         backgroundColor: Colors.white,
//         child: const Icon(Icons.my_location, color: Colors.blueAccent),
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:jaga/features/map/presentation/widgets/safety_check_dialog.dart';
import 'package:latlong2/latlong.dart';
import '../widgets/destination_search_bar.dart';
import '../../application/location_service.dart';
import '../../application/geocoding_service.dart';
import '../widgets/welcome_dialog.dart';
// import routing service
import '../../../routing/application/routing_service.dart';

class MainSafetyMapScreen extends ConsumerStatefulWidget {
  const MainSafetyMapScreen({
    required this.displayName,
    required this.onSignOut,
    super.key,
  });

  final String displayName;
  final Future<bool> Function() onSignOut;

  @override
  ConsumerState<MainSafetyMapScreen> createState() =>
      _MainSafetyMapScreenState();
}

class _MainSafetyMapScreenState extends ConsumerState<MainSafetyMapScreen> {
  final MapController _mapController = MapController();
  bool _hasInitialCameraMoved = false;

  @override
  void initState() {
    super.initState();

    // tunggu ui selesai build, baru panggil pop up
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showWelcomePopup();
    });
  }

  void _showWelcomePopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return WelcomeDialog(username: widget.displayName);
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
    // pake provider buat gps
    final locationAsyncValue = ref.watch(liveLocationProvider);

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

              // layer buat gambar garis rute
              PolylineLayer(
                polylines: [
                  // cuman draw kalau ga kosong, soalnya error dia kalau ga gini
                  if (ref.watch(routeProvider).isNotEmpty)
                    Polyline(
                      points: ref.watch(routeProvider),
                      strokeWidth: 5.0,
                      color: Colors.blueAccent,
                    ),
                ],
              ),

              // kalau ada data location, draw marker
              locationAsyncValue.when(
                data: (currentPosition) {
                  // pindah kamera pas pertama load
                  if (!_hasInitialCameraMoved) {
                    _hasInitialCameraMoved = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _mapController.move(currentPosition, 15.0);
                    });
                  }

                  // 1. cek kalau user udah cari tujuan
                  final destinationPosition = ref.watch(destinationProvider);

                  // 2. build list marker
                  List<Marker> mapMarkers = [
                    // marker biru buat user
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

                  // 3. kalau ada tujuan, tambahin pin merah ke map
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

                    // auto pindah kamera ke pin baru
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
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Expanded(child: DestinationSearchBar()),
                      const SizedBox(width: 10),
                      Material(
                        color: Colors.white,
                        elevation: 3,
                        shape: const CircleBorder(),
                        child: PopupMenuButton<String>(
                          tooltip: 'Akun',
                          icon: const Icon(
                            Icons.account_circle_outlined,
                            color: Colors.black87,
                          ),
                          onSelected: (value) async {
                            if (value != 'signOut') {
                              return;
                            }
                            final succeeded = await widget.onSignOut();
                            if (!succeeded && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Akun belum dapat dikeluarkan. Silakan coba lagi.',
                                  ),
                                ),
                              );
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem<String>(
                              enabled: false,
                              child: Text(
                                widget.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const PopupMenuDivider(),
                            const PopupMenuItem<String>(
                              value: 'signOut',
                              child: Row(
                                children: [
                                  Icon(Icons.logout_rounded, color: Colors.red),
                                  SizedBox(width: 10),
                                  Text('Keluar'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // tombol debug buat pop up danger
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      // pass dummy distance buat tes ui
                      _showSafetyCheckPopup(150);
                    },
                    icon: const Icon(Icons.bug_report),
                    label: const Text("DEBUG: Uji pop-up bahaya"),
                  ),

                  const SizedBox(height: 12), // kasi jarak buat tombol rute
                  // tombol debug buat tes rute
                  ElevatedButton(
                    onPressed: () async {
                      // ambil gps sekarang sama lokasi tujuan dari riverpod
                      final currentPosition = ref
                          .read(liveLocationProvider)
                          .value;
                      final destinationPosition = ref.read(destinationProvider);

                      // pastikan dua-duanya ga kosong
                      if (currentPosition != null &&
                          destinationPosition != null) {
                        // hit api ors
                        final routePoints = await RoutingService.getRoute(
                          currentPosition,
                          destinationPosition,
                        );

                        // update state biar polyline ke-gambar
                        ref
                            .read(routeProvider.notifier)
                            .updateRoute(routePoints);
                      } else {
                        // error handling kalau belum pilih tujuan atau gps belum dapet
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Tunggu GPS aktif dan pilih tujuan terlebih dahulu.',
                            ),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black87,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('DEBUG: Uji rute'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // fokus ke marker user
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

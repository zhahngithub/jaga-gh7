import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:jaga/core/constants/safety_constants.dart';
import 'package:jaga/features/auth/application/auth_providers.dart';
import 'package:jaga/features/distress/application/distress_controller.dart';
import 'package:jaga/features/distress/data/models/distress_session.dart';
import 'package:jaga/features/map/application/emergency_service.dart';
import 'package:jaga/features/map/presentation/widgets/emergency_notified_dialog.dart';
import 'package:jaga/features/map/presentation/widgets/active_distress_marker.dart';
import 'package:jaga/features/map/presentation/widgets/help_request_dialog.dart';
import 'package:jaga/features/map/presentation/widgets/nearby_notified_dialog.dart';
import 'package:jaga/features/map/presentation/widgets/pin_verification_dialog.dart';
import 'package:jaga/features/map/presentation/widgets/police_notified_dialog.dart';
import 'package:jaga/features/map/presentation/widgets/safety_check_dialog.dart';
import 'package:jaga/features/notifications/application/notification_routing_controller.dart';
import 'package:jaga/features/reports/application/report_controller.dart';
import 'package:jaga/features/reports/data/models/report.dart';
import 'package:jaga/features/reports/presentation/widgets/report_bottom_sheet.dart';
import 'package:jaga/features/reports/presentation/widgets/report_detail_bottom_sheet.dart';
import 'package:jaga/features/reports/presentation/widgets/report_marker_icon.dart';
import 'package:latlong2/latlong.dart';
import '../widgets/destination_search_bar.dart';
import '../../application/location_service.dart';
import '../../application/geocoding_service.dart';
import '../widgets/welcome_dialog.dart';
import '../../../routing/application/routing_service.dart';

class MainSafetyMapScreen extends ConsumerStatefulWidget {
  const MainSafetyMapScreen({
    required this.displayName,
    required this.onOpenProfile,
    required this.onSignOut,
    super.key,
  });

  final String displayName;
  final VoidCallback onOpenProfile;
  final Future<bool> Function() onSignOut;

  @override
  ConsumerState<MainSafetyMapScreen> createState() =>
      _MainSafetyMapScreenState();
}

class _MainSafetyMapScreenState extends ConsumerState<MainSafetyMapScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  final GlobalKey _mapKey = GlobalKey();
  final GlobalKey _searchHeaderKey = GlobalKey();
  late final AnimationController _reportCameraAnimation;
  bool _isCorrectingDraftCamera = false;
  bool _draftRecenterScheduled = false;
  bool _notificationNavigationScheduled = false;
  bool _isRouteLoading = false;
  Route<void>? _emergencyPopupRoute;
  String? _centeredDistressSessionId;
  double? _reportSheetTop;
  double? _lastObservedRotation;
  LatLng? _selectedReportLocation;
  LatLng? _cameraAnimationStart;
  LatLng? _cameraAnimationTarget;
  double _cameraAnimationStartZoom = 0;
  double _cameraAnimationTargetZoom = 0;

  @override
  void initState() {
    super.initState();
    _reportCameraAnimation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    )..addListener(_moveReportCameraAnimation);

    // tunggu ui selesai build, baru panggil pop up
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pendingSessionId = ref
          .read(notificationNavigationProvider)
          .pendingSessionId;
      if (pendingSessionId == null) {
        _showWelcomePopup();
      } else {
        _schedulePendingNotificationNavigation();
      }
    });
  }

  @override
  void dispose() {
    _reportCameraAnimation.dispose();
    super.dispose();
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
    _replaceEmergencyPopup(SafetyCheckDialog(distanceInMeters: distance));
  }

  void _showEmergencyNotifiedPopup() {
    _replaceEmergencyPopup(const EmergencyNotifiedDialog());
  }

  void _showNearbyNotifiedPopup() {
    _replaceEmergencyPopup(const NearbyNotifiedDialog());
  }

  void _showHelpRequestPopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => HelpRequestDialog(
        //TODO: this is place holder, maybe can implement count
        distanceInMeters: 10,
        onSeeLocation: () {
          Navigator.of(context).popUntil((route) => route.isFirst);
          ref
              .read(notificationNavigationProvider.notifier)
              .activatePendingSession();
        },
      ),
    );
  }

  void _showPoliceNotifiedPopup() {
    _replaceEmergencyPopup(
      const PoliceNotifiedDialog(policeStationName: 'Polda Metro Jaya'),
    );
  }

  void _replaceEmergencyPopup(Widget dialog) {
    if (!mounted) return;
    final navigator = Navigator.of(context, rootNavigator: true);
    _closeEmergencyPopup();

    final route = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => dialog,
    );
    _emergencyPopupRoute = route;
    unawaited(
      navigator.push(route).whenComplete(() {
        if (identical(_emergencyPopupRoute, route)) {
          _emergencyPopupRoute = null;
        }
      }),
    );
  }

  void _closeEmergencyPopup() {
    final route = _emergencyPopupRoute;
    if (route == null || !mounted) return;
    _emergencyPopupRoute = null;
    if (!route.isActive) return;

    final navigator = Navigator.of(context, rootNavigator: true);
    navigator.popUntil((candidate) => identical(candidate, route));
    if (route.isActive) navigator.pop();
  }

  Future<void> _startTrustedContactPhase() async {
    final started = await ref
        .read(distressControllerProvider.notifier)
        .startTrustedContactDistress();
    if (!started || !mounted) return;

    final phase = ref.read(emergencyProvider).phase;
    if (phase == EmergencyPhase.safe) {
      await ref.read(distressControllerProvider.notifier).stop();
    } else if (phase == EmergencyPhase.nearbyHelpers ||
        phase == EmergencyPhase.police) {
      await _startNearbyHelperPhase();
    }
  }

  Future<void> _startNearbyHelperPhase() async {
    final escalated = await ref
        .read(distressControllerProvider.notifier)
        .escalateToNearbyHelpers();
    if (!escalated || !mounted) return;
    if (ref.read(emergencyProvider).phase == EmergencyPhase.safe) {
      await ref.read(distressControllerProvider.notifier).stop();
    }
  }

  Future<void> _handleEmergencyStateChange(
    EmergencyState? previous,
    EmergencyState next,
  ) async {
    if (previous?.phase == next.phase) return;

    switch (next.phase) {
      case EmergencyPhase.safe:
        _closeEmergencyPopup();
        if (ref.read(distressControllerProvider).isActive) {
          await ref.read(distressControllerProvider.notifier).stop();
        }
        return;
      case EmergencyPhase.offTrackWarning:
        _showSafetyCheckPopup(next.offTrackDistanceMeters ?? _offTrackDistance);
        return;
      case EmergencyPhase.trustedContacts:
        _showEmergencyNotifiedPopup();
        unawaited(_startTrustedContactPhase());
        return;
      case EmergencyPhase.nearbyHelpers:
        _showNearbyNotifiedPopup();
        unawaited(_startNearbyHelperPhase());
        return;
      case EmergencyPhase.police:
        _showPoliceNotifiedPopup();
        return;
    }
  }

  void _schedulePendingNotificationNavigation() {
    if (_notificationNavigationScheduled) return;
    _notificationNavigationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notificationNavigationScheduled = false;
      if (!mounted) return;
      final navigation = ref.read(notificationNavigationProvider);
      if (navigation.pendingSessionId == null) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      ref
          .read(notificationNavigationProvider.notifier)
          .activatePendingSession();
    });
  }

  void _showDistressMessage(String message, {required bool isError}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red.shade700 : null,
        ),
      );
      ref.read(distressControllerProvider.notifier).clearFeedback();
    });
  }

  String _locationUnavailableMessage(AsyncValue<LatLng> location) {
    final errorText = location.error?.toString().toLowerCase() ?? '';
    if (errorText.contains('denied forever') ||
        errorText.contains('permanently denied')) {
      return 'Izin lokasi ditolak permanen. Aktifkan izin lokasi di pengaturan.';
    }
    if (errorText.contains('denied')) {
      return 'Izin lokasi diperlukan untuk mengirim sinyal darurat.';
    }
    if (errorText.contains('disabled')) {
      return 'Layanan lokasi sedang nonaktif.';
    }
    return 'Lokasi saat ini belum tersedia. Tunggu GPS lalu coba lagi.';
  }

  Offset? _visibleMapCenter() {
    final mapBox = _mapKey.currentContext?.findRenderObject() as RenderBox?;
    final headerBox =
        _searchHeaderKey.currentContext?.findRenderObject() as RenderBox?;
    final sheetTop = _reportSheetTop;

    if (mapBox == null ||
        headerBox == null ||
        sheetTop == null ||
        !mapBox.hasSize ||
        !headerBox.hasSize) {
      return null;
    }

    final mapTop = mapBox.localToGlobal(Offset.zero).dy;
    final availableTop =
        headerBox.localToGlobal(Offset(0, headerBox.size.height)).dy - mapTop;
    final availableBottom = sheetTop - mapTop;
    final clampedTop = availableTop.clamp(0.0, mapBox.size.height).toDouble();
    final clampedBottom = availableBottom
        .clamp(0.0, mapBox.size.height)
        .toDouble();

    if (clampedBottom <= clampedTop) return null;

    return Offset(mapBox.size.width / 2, (clampedTop + clampedBottom) / 2);
  }

  void _correctDraftCamera([MapCamera? updatedCamera]) {
    if (_isCorrectingDraftCamera) return;

    final draftLocation = ref.read(draftLocationProvider);
    final desiredScreenPoint = _visibleMapCenter();
    if (draftLocation == null || desiredScreenPoint == null) return;

    final camera = updatedCamera ?? _mapController.camera;
    final currentScreenPoint = camera.latLngToScreenOffset(draftLocation);
    final screenError = currentScreenPoint - desiredScreenPoint;
    if (screenError.distance < 0.5) return;

    final viewportCenter = Offset(
      camera.nonRotatedSize.width / 2,
      camera.nonRotatedSize.height / 2,
    );
    final correctedCenter = camera.screenOffsetToLatLng(
      viewportCenter + screenError,
    );

    _isCorrectingDraftCamera = true;
    try {
      _mapController.move(correctedCenter, camera.zoom);
    } finally {
      _isCorrectingDraftCamera = false;
    }
  }

  void _scheduleDraftCameraCorrection() {
    if (_draftRecenterScheduled) return;
    _draftRecenterScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _draftRecenterScheduled = false;
      if (mounted) _correctDraftCamera();
    });
  }

  void _handleReportSheetTopChanged(double top) {
    if (_reportSheetTop != null && (_reportSheetTop! - top).abs() < 0.5) {
      return;
    }
    _reportSheetTop = top;
    _scheduleDraftCameraCorrection();
  }

  void _moveReportCameraAnimation() {
    final start = _cameraAnimationStart;
    final target = _cameraAnimationTarget;
    if (start == null || target == null || !mounted) return;

    final progress = Curves.easeOutCubic.transform(
      _reportCameraAnimation.value,
    );
    final center = LatLng(
      start.latitude + (target.latitude - start.latitude) * progress,
      start.longitude + (target.longitude - start.longitude) * progress,
    );
    final zoom =
        _cameraAnimationStartZoom +
        (_cameraAnimationTargetZoom - _cameraAnimationStartZoom) * progress;

    _mapController.move(center, zoom);
  }

  void _animateSelectedReportCamera() {
    final reportLocation = _selectedReportLocation;
    final desiredScreenPoint = _visibleMapCenter();
    if (reportLocation == null || desiredScreenPoint == null) return;

    final camera = _mapController.camera;
    final targetZoom = camera.zoom < SafetyConstants.reportDetailZoom
        ? SafetyConstants.reportDetailZoom
        : camera.zoom;
    final targetCamera = camera.withPosition(zoom: targetZoom);
    final reportScreenPoint = targetCamera.latLngToScreenOffset(reportLocation);
    final screenError = reportScreenPoint - desiredScreenPoint;
    final viewportCenter = Offset(
      targetCamera.nonRotatedSize.width / 2,
      targetCamera.nonRotatedSize.height / 2,
    );
    final targetCenter = targetCamera.screenOffsetToLatLng(
      viewportCenter + screenError,
    );

    final centerAlreadyCorrect =
        camera.latLngToScreenOffset(reportLocation) - desiredScreenPoint;
    if (centerAlreadyCorrect.distance < 0.5 &&
        (camera.zoom - targetZoom).abs() < 0.01) {
      return;
    }

    _reportCameraAnimation.stop();
    _cameraAnimationStart = camera.center;
    _cameraAnimationTarget = targetCenter;
    _cameraAnimationStartZoom = camera.zoom;
    _cameraAnimationTargetZoom = targetZoom;
    _reportCameraAnimation.forward(from: 0);
  }

  void _handleReportDetailSheetTopChanged(double top) {
    if (_selectedReportLocation == null) return;
    if (_reportSheetTop != null && (_reportSheetTop! - top).abs() < 2) {
      return;
    }

    _reportSheetTop = top;
    _animateSelectedReportCamera();
  }

  void _handleMapPositionChanged(MapCamera camera, bool hasGesture) {
    if (hasGesture && _reportCameraAnimation.isAnimating) {
      _reportCameraAnimation.stop();
    }

    final previousRotation = _lastObservedRotation;
    _lastObservedRotation = camera.rotation;

    if (_isCorrectingDraftCamera || previousRotation == null) return;

    final rotationDelta =
        ((camera.rotation - previousRotation + 540) % 360) - 180;
    if (rotationDelta.abs() > 0.001) {
      _correctDraftCamera(camera);
    }
  }

  // dangerous route 100 meter
  bool _isRouteDangerous(List<LatLng> route, List<Report> hazards) {
    final distanceCalc = const Distance();
    for (final point in route) {
      for (final hazard in hazards) {
        final dist = distanceCalc.as(
          LengthUnit.Meter,
          point,
          LatLng(hazard.location.latitude, hazard.location.longitude),
        );
        if (dist <= 100.0) return true;
      }
    }
    return false;
  }

  bool _isSameLocation(LatLng? first, LatLng? second) {
    if (first == null || second == null) return first == second;
    return first.latitude == second.latitude &&
        first.longitude == second.longitude;
  }

  void _handleDestinationChanged(LatLng? previous, LatLng? next) {
    if (_isSameLocation(previous, next)) return;
    ref.read(routeProvider.notifier).clearRoutes();
    if (next == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !_isSameLocation(ref.read(destinationProvider), next)) {
        return;
      }
      _mapController.move(next, 15.0);
    });
  }

  Future<void> _startRoute(List<Report> visibleReports) async {
    if (_isRouteLoading) return;

    final currentPosition = ref.read(liveLocationProvider).value;
    final destinationPosition = ref.read(destinationProvider);
    if (currentPosition == null) {
      _showDistressMessage(
        _locationUnavailableMessage(ref.read(liveLocationProvider)),
        isError: true,
      );
      return;
    }
    if (destinationPosition == null) return;

    setState(() => _isRouteLoading = true);
    try {
      final hazards = visibleReports
          .where((report) => report.reportType != 'protective')
          .toList();
      final mainRoute = await RoutingService.getRoute(
        currentPosition,
        destinationPosition,
      );
      if (!mounted ||
          !_isSameLocation(ref.read(destinationProvider), destinationPosition)) {
        return;
      }
      if (mainRoute.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rute belum dapat dibuat. Coba lagi.')),
        );
        return;
      }

      final isDangerous = _isRouteDangerous(mainRoute, hazards);
      var safeRoute = <LatLng>[];
      if (isDangerous) {
        safeRoute = await RoutingService.getRoute(
          currentPosition,
          destinationPosition,
          hazards: hazards,
        );
        if (!mounted ||
            !_isSameLocation(
              ref.read(destinationProvider),
              destinationPosition,
            )) {
          return;
        }
        if (safeRoute.isEmpty || _isRouteDangerous(safeRoute, hazards)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Rute alternatif aman belum dapat ditemukan.'),
            ),
          );
          return;
        }
      }

      ref
          .read(routeProvider.notifier)
          .updateRoutes(main: mainRoute, safe: safeRoute);
    } finally {
      if (mounted) setState(() => _isRouteLoading = false);
    }
  }

  // red blue route
  List<Polyline> _buildColoredRoute(
    List<LatLng> routePoints,
    List<Report> hazards,
  ) {
    if (routePoints.isEmpty) return [];

    final distanceCalc = const Distance();
    const double dangerRadius = 100.0; // 100 meter

    List<Polyline> polylines = [];
    List<LatLng> currentSegment = [routePoints.first];

    // titik awal
    bool wasInDanger = hazards.any(
      (hazard) =>
          distanceCalc.as(
            LengthUnit.Meter,
            routePoints.first,
            LatLng(hazard.location.latitude, hazard.location.longitude),
          ) <=
          dangerRadius,
    );

    for (int i = 1; i < routePoints.length; i++) {
      final point = routePoints[i];

      // check each point
      final isInDanger = hazards.any(
        (hazard) =>
            distanceCalc.as(
              LengthUnit.Meter,
              point,
              LatLng(hazard.location.latitude, hazard.location.longitude),
            ) <=
            dangerRadius,
      );

      // same status
      if (isInDanger == wasInDanger) {
        currentSegment.add(point);
      } else {
        // change status
        currentSegment.add(point);
        polylines.add(
          Polyline(
            points: currentSegment,
            strokeWidth: 5.0,
            color: wasInDanger ? Colors.redAccent : Colors.blueAccent,
          ),
        );
        currentSegment = [point];
        wasInDanger = isInDanger;
      }
    }

    // draw line sisa
    if (currentSegment.length > 1) {
      polylines.add(
        Polyline(
          points: currentSegment,
          strokeWidth: 5.0,
          color: wasInDanger ? Colors.redAccent : Colors.blueAccent,
        ),
      );
    }

    return polylines;
  }

  // INI BAGIAN BUAT CEK OFF TRACK
  int _offTrackDistance = 0;

  // Fungsi buat ngecek jarak terdekat dari user ke garis rute
  double _calculateDistanceToRoute(LatLng currentPos, List<LatLng> route) {
    if (route.isEmpty) return 0.0;

    final distance = const Distance();
    double minDistance = double.infinity;

    // Hackathon trick: Loop koordinat rute untuk cari titik terdekat
    for (final point in route) {
      final dist = distance.as(LengthUnit.Meter, currentPos, point);
      if (dist < minDistance) {
        minDistance = dist;
      }
    }
    return minDistance;
  }

  // Menu pilihan saat map di-klik
  void _showMapActionMenu(LatLng location) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(
                Icons.report_problem_rounded,
                color: Colors.orange,
              ),
              title: const Text('Lapor Lokasi'),
              subtitle: const Text(
                'Tambahkan laporan bahaya atau aman di titik ini',
              ),
              onTap: () {
                Navigator.pop(context); // Tutup menu
                _openReportSheet(location); // Buka form report
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.directions_walk,
                color: Colors.blueAccent,
              ),
              title: const Text('Jadikan Tujuan'),
              subtitle: const Text('Arahkan rute navigasi ke titik ini'),
              onTap: () {
                Navigator.pop(context); // Tutup menu
                ref.read(destinationProvider.notifier).updateLocation(location);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // Logika asli form report yang dipindah ke function terpisah
  void _openReportSheet(LatLng location) async {
    FocusScope.of(context).unfocus();
    ref.read(searchResultsVisibleProvider.notifier).hide();
    _reportSheetTop = null;
    ref.read(draftLocationProvider.notifier).setLocation(location);

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        barrierColor: Colors.transparent,
        builder: (_) => _ReportSheetBoundsObserver(
          onTopChanged: _handleReportSheetTopChanged,
          child: ReportBottomSheet(location: location),
        ),
      );
    } finally {
      if (mounted) {
        _reportSheetTop = null;
        ref.read(draftLocationProvider.notifier).clear();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // pake provider buat gps
    final locationAsyncValue = ref.watch(liveLocationProvider);
    final draftLocation = ref.watch(draftLocationProvider);
    final reportsAsync = ref.watch(visibleReportsProvider);
    final visibleReports = reportsAsync.value ?? const <Report>[];
    final distressState = ref.watch(distressControllerProvider);
    final emergencyState = ref.watch(emergencyProvider);
    final destinationPosition = ref.watch(destinationProvider);
    final routeState = ref.watch(routeProvider);
    final authSession = ref.watch(authenticationStateProvider).value;
    final senderSessionId = distressState.activeSessionId;
    final senderSession = senderSessionId == null
        ? null
        : ref.watch(distressSessionProvider(senderSessionId));
    final activeSenderSession = senderSession?.value;
    final activeSenderLocation =
        activeSenderSession?.isActive == true &&
            activeSenderSession?.senderUid == authSession?.uid
        ? locationAsyncValue.value ?? activeSenderSession?.preciseLocation
        : null;
    final notificationNavigation = ref.watch(notificationNavigationProvider);
    final viewedSessionId = notificationNavigation.viewedSessionId;
    final viewedSession = viewedSessionId == null
        ? null
        : ref.watch(distressSessionProvider(viewedSessionId));
    final distressSession = viewedSession?.value;

    ref.listen<NotificationNavigationState>(notificationNavigationProvider, (
      previous,
      next,
    ) {
      if (next.pendingSessionId != null &&
          next.pendingSessionId != previous?.pendingSessionId) {
        _showHelpRequestPopup();
      }
    });

    ref.listen<DistressState>(distressControllerProvider, (previous, next) {
      final message = next.feedbackMessage;
      if (message != null && message != previous?.feedbackMessage) {
        _showDistressMessage(message, isError: next.feedbackIsError);
      }
    });

    ref.listen<LatLng?>(destinationProvider, _handleDestinationChanged);

    if (viewedSessionId != null &&
        distressSession != null &&
        _centeredDistressSessionId != viewedSessionId) {
      _centeredDistressSessionId = viewedSessionId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _mapController.move(distressSession.preciseLocation, 16);
        }
      });
    }

    ref.listen<EmergencyState>(emergencyProvider, _handleEmergencyStateChange);

    // listener buat off track
    ref.listen(liveLocationProvider, (previous, next) {
      final currentPos = next.value;
      final currentEmergencyState = ref.read(emergencyProvider);
      final routeState = ref.read(routeProvider);

      // Prioritaskan safeRoute kalau ada, kalau ga ada pake mainRoute
      final activeRoute = routeState.safeRoute.isNotEmpty
          ? routeState.safeRoute
          : routeState.mainRoute;

      if (currentPos == null || activeRoute.isEmpty) return;

      final distanceToRoute = _calculateDistanceToRoute(
        currentPos,
        activeRoute,
      );
      final distanceInMeters = distanceToRoute.toInt();
      if (currentEmergencyState.phase == EmergencyPhase.offTrackWarning) {
        _offTrackDistance = distanceInMeters;
        ref
            .read(emergencyProvider.notifier)
            .updateOffTrackDistance(distanceInMeters);
      } else if (currentEmergencyState.phase == EmergencyPhase.safe &&
          distanceToRoute > 100.0) {
        _offTrackDistance = distanceInMeters;
        ref
            .read(emergencyProvider.notifier)
            .triggerWarning(distanceInMeters: distanceInMeters);
      }
    });

    return Stack(
      children: [
        Positioned.fill(
          child: Scaffold(
            body: Stack(
        children: [
          FlutterMap(
            key: _mapKey,
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(-6.1783, 106.6319), // fallback
              initialZoom: 13.0,
              onMapReady: () {
                _lastObservedRotation = _mapController.camera.rotation;
              },
              onPositionChanged: _handleMapPositionChanged,
              onTap: (_, location) {
                FocusScope.of(context).unfocus();
                _showMapActionMenu(location);
              },
              onLongPress: (_, location) {
                FocusScope.of(context).unfocus();
                _showMapActionMenu(location);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.yourname.jaga',
              ),

              // layer buat gambar garis rute
              PolylineLayer(
                polylines: () {
                  final hazards = visibleReports
                      .where((r) => r.reportType != 'protective')
                      .toList();

                  final hasSafeAlternative = routeState.safeRoute.isNotEmpty;
                  final allLines = hasSafeAlternative
                      ? <Polyline>[
                          Polyline(
                            points: routeState.mainRoute,
                            strokeWidth: 5.0,
                            color: Colors.redAccent,
                          ),
                        ]
                      : List<Polyline>.from(
                          _buildColoredRoute(routeState.mainRoute, hazards),
                        );

                  if (hasSafeAlternative) {
                    allLines.add(
                      Polyline(
                        points: routeState.safeRoute,
                        strokeWidth: 6.0,
                        color: Colors.lightBlueAccent,
                        borderColor: Colors.blue.shade900,
                        borderStrokeWidth: 2.0,
                      ),
                    );
                  }

                  return allLines;
                }(),
              ),

              // lingkaran tiap marker
              CircleLayer(
                circles: visibleReports
                    // Only draw circles for hazard reports (ignore police/cctv)
                    .where((report) => report.reportType != 'protective')
                    .map((report) {
                      return CircleMarker(
                        point: LatLng(
                          report.location.latitude,
                          report.location.longitude,
                        ),
                        color: Colors.red.withValues(
                          alpha: 0.2,
                        ), // Transparent red fill
                        borderColor: Colors.redAccent, // Solid red border
                        borderStrokeWidth: 2,
                        useRadiusInMeter: true,
                        radius: 100.0, // 50 meter radius
                      );
                    })
                    .toList(),
              ),

              // kalau ada data location, draw marker
              locationAsyncValue.when(
                data: (currentPosition) {
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

                  }

                  return MarkerLayer(markers: mapMarkers);
                },
                loading: () => const SizedBox.shrink(),
                error: (error, stack) => const SizedBox.shrink(),
              ),

              // draft report + submitted report markers
              MarkerLayer(
                rotate: true,
                markers: [
                  if (draftLocation != null)
                    Marker(
                      point: draftLocation,
                      width: 72,
                      height: 64,
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add_location_alt,
                            color: Colors.purple,
                            size: 42,
                          ),
                          Text(
                            'DRAFT',
                            style: TextStyle(
                              color: Colors.purple,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ...visibleReports.map(
                    (report) => Marker(
                      point: LatLng(
                        report.location.latitude,
                        report.location.longitude,
                      ),
                      width: 48,
                      height: 48,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () async {
                          FocusScope.of(context).unfocus();
                          _reportSheetTop = null;
                          _selectedReportLocation = LatLng(
                            report.location.latitude,
                            report.location.longitude,
                          );

                          try {
                            await showModalBottomSheet<void>(
                              context: context,
                              isScrollControlled: true,
                              useSafeArea: true,
                              barrierColor: Colors.transparent,
                              builder: (_) => _ReportSheetBoundsObserver(
                                reportDuringTransition: false,
                                onTopChanged:
                                    _handleReportDetailSheetTopChanged,
                                child: ReportDetailBottomSheet(
                                  initialReport: report,
                                ),
                              ),
                            );
                          } finally {
                            if (mounted) {
                              _reportCameraAnimation.stop();
                              _selectedReportLocation = null;
                              _reportSheetTop = null;
                            }
                          }
                        },
                        child: Tooltip(
                          message: report.category.replaceAll('_', ' '),
                          child: reportMarkerIcon(report),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (activeSenderLocation != null)
                MarkerLayer(
                  rotate: true,
                  markers: [
                    Marker(
                      point: activeSenderLocation,
                      width: 116,
                      height: 116,
                      child: const IgnorePointer(child: ActiveDistressMarker()),
                    ),
                  ],
                ),
              if (distressSession?.isActive == true)
                MarkerLayer(
                  rotate: true,
                  markers: [
                    Marker(
                      point: distressSession!.preciseLocation,
                      width: 76,
                      height: 76,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.red.shade700,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black38,
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.sos_rounded,
                          color: Colors.white,
                          size: 38,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Column(
                    key: _searchHeaderKey,
                    mainAxisSize: MainAxisSize.min,
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
                                if (value == 'profile') {
                                  widget.onOpenProfile();
                                  return;
                                }
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
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                                const PopupMenuDivider(),
                                const PopupMenuItem<String>(
                                  value: 'profile',
                                  child: Row(
                                    children: [
                                      Icon(Icons.person_outline_rounded),
                                      SizedBox(width: 10),
                                      Text('Profil & Pengaturan'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem<String>(
                                  value: 'signOut',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.logout_rounded,
                                        color: Colors.red,
                                      ),
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
                    ],
                  ),

                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (destinationPosition != null && routeState.mainRoute.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: FloatingActionButton.extended(
                heroTag: 'btn_start_route',
                onPressed: _isRouteLoading
                    ? null
                    : () => _startRoute(visibleReports),
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                icon: _isRouteLoading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.directions_rounded),
                label: Text(
                  _isRouteLoading ? 'Membuat Rute...' : 'Mulai Rute',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),

          // 1. TOMBOL BATALKAN RUTE (Hanya muncul jika ada tujuan)
          if (destinationPosition != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: FloatingActionButton.extended(
                heroTag: "btn_cancel_route",
                onPressed: () {
                  // Hapus tujuan dan garis rute dari state
                  ref.invalidate(destinationProvider);
                  ref.read(routeProvider.notifier).clearRoutes();
                },
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                icon: const Icon(Icons.close_rounded, color: Colors.red),
                label: const Text("Batalkan Rute"),
              ),
            ),

          // 2. TOMBOL SOS DARURAT (Dengan verifikasi PIN saat membatalkan)
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: FloatingActionButton.extended(
              heroTag: "btn_sos",
              onPressed: distressState.isLoading
                  ? null
                  : () async {
                      // Kalau lagi aktif, minta PIN buat matiin
                      if (distressState.isActive || emergencyState.isActive) {
                        final isVerified = await showPinVerificationDialog(
                          context,
                          reason: 'membatalkan status darurat',
                        );

                        if (isVerified) {
                          if (emergencyState.isActive) {
                            ref.read(emergencyProvider.notifier).markAsSafe();
                          } else {
                            await ref
                                .read(distressControllerProvider.notifier)
                                .stop();
                          }
                        }
                        return;
                      }

                      // Mulai langsung dari fase kontak darurat.
                      final currentLocation = ref
                          .read(liveLocationProvider)
                          .value;
                      if (currentLocation == null) {
                        _showDistressMessage(
                          _locationUnavailableMessage(
                            ref.read(liveLocationProvider),
                          ),
                          isError: true,
                        );
                        return;
                      }

                      ref
                          .read(emergencyProvider.notifier)
                          .triggerEmergencyNow();
                    },
              backgroundColor: distressState.isActive || emergencyState.isActive
                  ? Colors.grey
                  : Colors.red,
              foregroundColor: Colors.white,
              elevation: 4,
              icon: distressState.isLoading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.sos_rounded, size: 28),
              label: Text(
                distressState.isActive || emergencyState.isActive
                    ? "HENTIKAN SOS"
                    : "DARURAT",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),

          // 3. TOMBOL MY LOCATION (Kembali ke titik GPS)
          FloatingActionButton(
            heroTag: "btn_location",
            onPressed: () {
              final currentPosition = ref.read(liveLocationProvider).value;
              if (currentPosition != null) {
                _mapController.move(currentPosition, 15.0);
              }
            },
            backgroundColor: Colors.white,
            elevation: 4,
            child: const Icon(Icons.my_location, color: Colors.blueAccent),
          ),
            ],
          ),
        ),
        ),
        if (viewedSession != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 88,
            child: _DistressSessionBanner(
              session: distressSession,
              isLoading: viewedSession.isLoading,
              errorMessage: viewedSession.hasError
                  ? viewedSession.error.toString()
                  : null,
              onDismiss: () {
                _centeredDistressSessionId = null;
                ref
                    .read(notificationNavigationProvider.notifier)
                    .clearViewedSession();
              },
            ),
          ),
      ],
    );
  }
}

class _DistressSessionBanner extends StatelessWidget {
  const _DistressSessionBanner({
    required this.session,
    required this.isLoading,
    required this.errorMessage,
    required this.onDismiss,
  });

  final DistressSession? session;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final currentSession = session;
    final status = currentSession?.effectiveStatus;
    final statusLabel = switch (status) {
      DistressStatus.active => 'Aktif',
      DistressStatus.ended => 'Berakhir',
      DistressStatus.expired => 'Kedaluwarsa',
      null => 'Tidak tersedia',
    };
    final accentColor = switch (status) {
      DistressStatus.active => Colors.red.shade700,
      DistressStatus.expired => Colors.orange.shade800,
      _ => Colors.grey.shade700,
    };

    return Material(
      elevation: 6,
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            if (isLoading)
              const SizedBox.square(
                dimension: 28,
                child: CircularProgressIndicator(strokeWidth: 3),
              )
            else
              Icon(
                status == DistressStatus.active
                    ? Icons.sos_rounded
                    : Icons.info_outline_rounded,
                color: accentColor,
                size: 32,
              ),
            const SizedBox(width: 12),
            Expanded(
              child: errorMessage != null
                  ? Text(
                      'Sesi tidak dapat dibuka: $errorMessage',
                      style: TextStyle(color: accentColor),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          currentSession?.senderDisplayName ??
                              'Memuat sesi darurat…',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        if (currentSession != null)
                          Text(
                            'Status: $statusLabel • Diperbarui ${_formatUpdatedAt(currentSession.updatedAt)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
            ),
            IconButton(
              tooltip: 'Tutup lokasi darurat',
              onPressed: onDismiss,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatUpdatedAt(DateTime? value) {
    if (value == null) return 'belum tersedia';
    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final second = local.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }
}

class _ReportSheetBoundsObserver extends StatefulWidget {
  const _ReportSheetBoundsObserver({
    required this.onTopChanged,
    required this.child,
    this.reportDuringTransition = true,
  });

  final ValueChanged<double> onTopChanged;
  final Widget child;
  final bool reportDuringTransition;

  @override
  State<_ReportSheetBoundsObserver> createState() =>
      _ReportSheetBoundsObserverState();
}

class _ReportSheetBoundsObserverState extends State<_ReportSheetBoundsObserver>
    with WidgetsBindingObserver {
  final GlobalKey _boundsKey = GlobalKey();
  Animation<double>? _routeAnimation;
  bool _measurementScheduled = false;
  double? _lastReportedTop;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final animation = ModalRoute.of(context)?.animation;
    if (!identical(animation, _routeAnimation)) {
      _routeAnimation?.removeListener(_scheduleMeasurement);
      _routeAnimation?.removeStatusListener(_handleRouteAnimationStatus);
      _routeAnimation = animation;
      if (widget.reportDuringTransition) {
        _routeAnimation?.addListener(_scheduleMeasurement);
      }
      _routeAnimation?.addStatusListener(_handleRouteAnimationStatus);
    }
    _scheduleMeasurement();
  }

  @override
  void didUpdateWidget(covariant _ReportSheetBoundsObserver oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reportDuringTransition != widget.reportDuringTransition) {
      if (widget.reportDuringTransition) {
        _routeAnimation?.addListener(_scheduleMeasurement);
      } else {
        _routeAnimation?.removeListener(_scheduleMeasurement);
      }
    }
    _scheduleMeasurement();
  }

  void _handleRouteAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _scheduleMeasurement();
    }
  }

  @override
  void didChangeMetrics() {
    _scheduleMeasurement();
  }

  void _scheduleMeasurement() {
    if (_measurementScheduled) return;
    _measurementScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measurementScheduled = false;
      if (!mounted) return;
      final routeStatus = _routeAnimation?.status;
      if (!widget.reportDuringTransition &&
          routeStatus != null &&
          routeStatus != AnimationStatus.completed) {
        return;
      }

      final box = _boundsKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return;

      final top = box.localToGlobal(Offset.zero).dy;
      if (_lastReportedTop != null && (_lastReportedTop! - top).abs() < 0.5) {
        return;
      }

      _lastReportedTop = top;
      widget.onTopChanged(top);
    });
  }

  @override
  void dispose() {
    _routeAnimation?.removeListener(_scheduleMeasurement);
    _routeAnimation?.removeStatusListener(_handleRouteAnimationStatus);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _scheduleMeasurement();

    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (_) {
        _scheduleMeasurement();
        return false;
      },
      child: SizeChangedLayoutNotifier(
        child: KeyedSubtree(key: _boundsKey, child: widget.child),
      ),
    );
  }
}

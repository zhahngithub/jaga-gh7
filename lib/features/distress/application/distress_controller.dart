import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:jaga/core/constants/safety_constants.dart';
import 'package:jaga/features/auth/application/auth_providers.dart';
import 'package:jaga/features/map/application/location_service.dart';
import 'package:latlong2/latlong.dart';

import '../data/models/distress_session.dart';
import '../data/repositories/distress_repository.dart';

class DistressState {
  const DistressState({
    this.isLoading = false,
    this.activeSessionId,
    this.feedbackMessage,
    this.feedbackIsError = false,
  });

  final bool isLoading;
  final String? activeSessionId;
  final String? feedbackMessage;
  final bool feedbackIsError;

  bool get isActive => activeSessionId != null;
}

final distressRepositoryProvider = Provider<DistressRepository>((ref) {
  return DistressRepository.firebase();
});

final distressSessionProvider = StreamProvider.family<DistressSession, String>((
  ref,
  sessionId,
) {
  return ref.watch(distressRepositoryProvider).watchSession(sessionId);
});

final distressControllerProvider =
    NotifierProvider<DistressController, DistressState>(DistressController.new);

class DistressController extends Notifier<DistressState> {
  Timer? _locationTimer;
  LatLng? _lastSentLocation;
  bool _locationUpdateInFlight = false;

  @override
  DistressState build() {
    ref.onDispose(_stopLocationUpdater);
    ref.listen(authenticationStateProvider, (_, next) {
      if (next.value == null) {
        _stopLocationUpdater();
        state = const DistressState();
      }
    });
    return const DistressState();
  }

  Future<void> toggle(LatLng location) async {
    if (state.isLoading) return;
    if (state.isActive) {
      await stop();
    } else {
      await start(location);
    }
  }

  Future<void> start(LatLng location) async {
    state = const DistressState(isLoading: true);
    try {
      final result = await ref
          .read(distressRepositoryProvider)
          .startSession(location);
      _lastSentLocation = location;
      state = DistressState(
        activeSessionId: result.sessionId,
        feedbackMessage: 'Sinyal darurat dibagikan kepada helper aktif.',
      );
      _startLocationUpdater();
    } on DistressDataException catch (error) {
      state = DistressState(
        feedbackMessage: error.message,
        feedbackIsError: true,
      );
    } on Object {
      state = const DistressState(
        feedbackMessage: 'Sinyal darurat belum dapat dikirim.',
        feedbackIsError: true,
      );
    }
  }

  Future<bool> startTrustedContactDistress() async {
    if (state.isLoading) return false;
    final activeSessionId = state.activeSessionId;
    if (activeSessionId != null) {
      state = DistressState(
        activeSessionId: activeSessionId,
        feedbackMessage: 'Sesi darurat sudah aktif.',
      );
      return true;
    }
    if (ref.read(authenticationStateProvider).value == null) {
      state = const DistressState(
        feedbackMessage: 'Masuk ke akun Jaga terlebih dahulu.',
        feedbackIsError: true,
      );
      return false;
    }
    final locationState = ref.read(liveLocationProvider);
    final location = locationState.value;
    if (location == null) {
      final error = locationState.error?.toString().toLowerCase() ?? '';
      state = DistressState(
        feedbackMessage: error.contains('denied')
            ? 'Izin lokasi diperlukan untuk mengirim lokasi darurat.'
            : 'Lokasi terkini belum tersedia. Silakan coba lagi.',
        feedbackIsError: true,
      );
      return false;
    }

    state = const DistressState(isLoading: true);
    try {
      final repository = ref.read(distressRepositoryProvider);
      final existingSessionId = await repository.findActiveOwnedSessionId();
      if (existingSessionId != null) {
        _lastSentLocation = location;
        state = DistressState(
          activeSessionId: existingSessionId,
          feedbackMessage: 'Sesi darurat sudah aktif.',
        );
        _startLocationUpdater();
        return true;
      }
      final recipients = await repository.loadTrustedContactRecipients();
      if (recipients.isEmpty) {
        throw const DistressDataException(
          'Tidak ada kontak darurat yang terhubung dengan akun Jaga.',
        );
      }
      final result = await repository.startTrustedContactSession(
        location: location,
        recipientUids: recipients.uids,
        recipientDisplayNames: recipients.displayNames,
      );
      _lastSentLocation = location;
      state = DistressState(
        activeSessionId: result.sessionId,
        feedbackMessage:
            'Lokasi langsung dikirim ke ${result.recipientCount} kontak darurat.',
      );
      _startLocationUpdater();
      return true;
    } on DistressDataException catch (error) {
      state = DistressState(
        feedbackMessage: error.message,
        feedbackIsError: true,
      );
      return false;
    } on Object {
      state = const DistressState(
        feedbackMessage:
            'Sinyal darurat belum dapat dikirim. Silakan coba lagi.',
        feedbackIsError: true,
      );
      return false;
    }
  }

  Future<void> stop() async {
    final sessionId = state.activeSessionId;
    if (sessionId == null || state.isLoading) return;
    _stopLocationUpdater();
    state = DistressState(isLoading: true, activeSessionId: sessionId);
    try {
      await ref.read(distressRepositoryProvider).stopSession(sessionId);
      state = const DistressState(feedbackMessage: 'Sesi darurat dihentikan.');
    } on DistressDataException catch (error) {
      state = DistressState(
        activeSessionId: sessionId,
        feedbackMessage: error.message,
        feedbackIsError: true,
      );
      _startLocationUpdater();
    } on Object {
      state = DistressState(
        activeSessionId: sessionId,
        feedbackMessage: 'Sesi darurat belum dapat dihentikan.',
        feedbackIsError: true,
      );
      _startLocationUpdater();
    }
  }

  void clearFeedback() {
    if (state.feedbackMessage == null) return;
    state = DistressState(
      isLoading: state.isLoading,
      activeSessionId: state.activeSessionId,
    );
  }

  void _startLocationUpdater() {
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(
      const Duration(
        seconds: SafetyConstants.alertLocationWriteIntervalSeconds,
      ),
      (_) => unawaited(_sendLatestLocation()),
    );
  }

  Future<void> _sendLatestLocation() async {
    final sessionId = state.activeSessionId;
    final location = ref.read(liveLocationProvider).value;
    if (sessionId == null || location == null || _locationUpdateInFlight) {
      return;
    }
    final previous = _lastSentLocation;
    if (previous != null) {
      final distance = Geolocator.distanceBetween(
        previous.latitude,
        previous.longitude,
        location.latitude,
        location.longitude,
      );
      if (distance < SafetyConstants.distressLocationWriteDistanceM) {
        return;
      }
    }
    _locationUpdateInFlight = true;
    try {
      await ref
          .read(distressRepositoryProvider)
          .updateLocation(sessionId, location);
      _lastSentLocation = location;
    } on Object {
      // A transient update failure is retried on the next timer tick.
    } finally {
      _locationUpdateInFlight = false;
    }
  }

  void _stopLocationUpdater() {
    _locationTimer?.cancel();
    _locationTimer = null;
    _locationUpdateInFlight = false;
    _lastSentLocation = null;
  }
}

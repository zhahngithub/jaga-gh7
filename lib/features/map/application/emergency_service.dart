import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

enum EmergencyPhase {
  safe,
  offTrackWarning,
  trustedContacts,
  nearbyHelpers,
  police,
}

class EmergencyState {
  const EmergencyState({
    this.phase = EmergencyPhase.safe,
    this.secondsRemaining,
    this.offTrackDistanceMeters,
  });

  final EmergencyPhase phase;
  final int? secondsRemaining;
  final int? offTrackDistanceMeters;

  bool get isActive => phase != EmergencyPhase.safe;
}

class EmergencyNotifier extends Notifier<EmergencyState> {
  static const int phaseCountdownSeconds = 30;

  Timer? _timer;

  @override
  EmergencyState build() {
    ref.onDispose(_cancelTimer);
    return const EmergencyState();
  }

  void triggerWarning({
    int? distanceInMeters,
    int countdownSeconds = phaseCountdownSeconds,
  }) {
    _startCountdown(
      phase: EmergencyPhase.offTrackWarning,
      seconds: countdownSeconds,
      offTrackDistanceMeters: distanceInMeters,
      onFinished: triggerEmergencyNow,
    );
  }

  void updateOffTrackDistance(int distanceInMeters) {
    if (state.phase != EmergencyPhase.offTrackWarning ||
        state.offTrackDistanceMeters == distanceInMeters) {
      return;
    }
    state = EmergencyState(
      phase: state.phase,
      secondsRemaining: state.secondsRemaining,
      offTrackDistanceMeters: distanceInMeters,
    );
  }

  void triggerEmergencyNow({
    int countdownSeconds = phaseCountdownSeconds,
  }) {
    _startCountdown(
      phase: EmergencyPhase.trustedContacts,
      seconds: countdownSeconds,
      onFinished: notifyNearbyHelpers,
    );
  }

  void notifyNearbyHelpers({
    int countdownSeconds = phaseCountdownSeconds,
  }) {
    _startCountdown(
      phase: EmergencyPhase.nearbyHelpers,
      seconds: countdownSeconds,
      onFinished: notifyPolice,
    );
  }

  void notifyPolice() {
    _cancelTimer();
    state = const EmergencyState(phase: EmergencyPhase.police);
  }

  void markAsSafe() {
    _cancelTimer();
    state = const EmergencyState();
  }

  void _startCountdown({
    required EmergencyPhase phase,
    required int seconds,
    required void Function() onFinished,
    int? offTrackDistanceMeters,
  }) {
    _cancelTimer();
    final normalizedSeconds = seconds < 0 ? 0 : seconds;
    state = EmergencyState(
      phase: phase,
      secondsRemaining: normalizedSeconds,
      offTrackDistanceMeters: offTrackDistanceMeters,
    );

    if (normalizedSeconds == 0) {
      onFinished();
      return;
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.phase != phase) {
        timer.cancel();
        return;
      }

      final secondsRemaining = (state.secondsRemaining ?? 1) - 1;
      if (secondsRemaining <= 0) {
        timer.cancel();
        _timer = null;
        onFinished();
        return;
      }

      state = EmergencyState(
        phase: phase,
        secondsRemaining: secondsRemaining,
        offTrackDistanceMeters: state.offTrackDistanceMeters,
      );
    });
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }
}

final emergencyProvider = NotifierProvider<EmergencyNotifier, EmergencyState>(
  EmergencyNotifier.new,
);

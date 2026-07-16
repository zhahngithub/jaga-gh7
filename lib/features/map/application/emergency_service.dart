import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum EmergencyStatus { safe, warning, notifying }

class EmergencyNotifier extends Notifier<EmergencyStatus> {
  Timer? _timer;

  @override
  EmergencyStatus build() {
    return EmergencyStatus.safe;
  }

  void triggerWarning() {
    state = EmergencyStatus.warning;
    
    // 30 sec countdown
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 3), () {

      if (state == EmergencyStatus.warning) {
        state = EmergencyStatus.notifying;
      }
    });
  }

  void markAsSafe() {
    _timer?.cancel();
    state = EmergencyStatus.safe;
  }

  void triggerEmergencyNow() {
    _timer?.cancel();
    state = EmergencyStatus.notifying;
  }
}

final emergencyProvider = NotifierProvider<EmergencyNotifier, EmergencyStatus>(() {
  return EmergencyNotifier();
});
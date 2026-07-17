import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jaga/features/map/application/emergency_service.dart';

void main() {
  testWidgets('off-track countdown advances to trusted contacts', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container
        .read(emergencyProvider.notifier)
        .triggerWarning(distanceInMeters: 142, countdownSeconds: 2);

    expect(
      container.read(emergencyProvider).phase,
      EmergencyPhase.offTrackWarning,
    );
    expect(container.read(emergencyProvider).secondsRemaining, 2);
    expect(container.read(emergencyProvider).offTrackDistanceMeters, 142);

    await tester.pump(const Duration(seconds: 1));
    expect(container.read(emergencyProvider).secondsRemaining, 1);

    await tester.pump(const Duration(seconds: 1));
    expect(
      container.read(emergencyProvider).phase,
      EmergencyPhase.trustedContacts,
    );
    expect(
      container.read(emergencyProvider).secondsRemaining,
      EmergencyNotifier.phaseCountdownSeconds,
    );
    container.read(emergencyProvider.notifier).markAsSafe();
  });

  testWidgets('nearby countdown advances to police without another timer', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container
        .read(emergencyProvider.notifier)
        .notifyNearbyHelpers(countdownSeconds: 2);
    await tester.pump(const Duration(seconds: 2));

    expect(container.read(emergencyProvider).phase, EmergencyPhase.police);
    expect(container.read(emergencyProvider).secondsRemaining, isNull);
  });

  testWidgets('marking safe cancels the active countdown', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(emergencyProvider.notifier);
    notifier.triggerEmergencyNow(countdownSeconds: 2);
    notifier.markAsSafe();
    await tester.pump(const Duration(seconds: 3));

    expect(container.read(emergencyProvider).phase, EmergencyPhase.safe);
    expect(container.read(emergencyProvider).secondsRemaining, isNull);
  });

  test('off-track distance can update while the warning remains active', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(emergencyProvider.notifier);
    notifier.triggerWarning(distanceInMeters: 110);
    notifier.updateOffTrackDistance(175);

    expect(
      container.read(emergencyProvider).phase,
      EmergencyPhase.offTrackWarning,
    );
    expect(container.read(emergencyProvider).offTrackDistanceMeters, 175);
  });
}

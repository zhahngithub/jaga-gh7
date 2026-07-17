import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jaga/features/map/application/emergency_service.dart';

class SafetyCheckDialog extends ConsumerWidget {
  final int distanceInMeters;

  const SafetyCheckDialog({super.key, required this.distanceInMeters});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded, size: 80, color: Colors.red),
            const SizedBox(height: 16),

            Text(
              "Apakah kamu dalam bahaya?",
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            Text(
              "Kamu $distanceInMeters meter diluar jalur utama.",
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Emergency Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  ref.read(emergencyProvider.notifier).triggerEmergencyNow();
                },
                child: const Text("Iya, aku dalam bahaya!"),
              ),
            ),
            const SizedBox(height: 12),

            // Safe Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: Colors.grey),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  ref.read(emergencyProvider.notifier).markAsSafe();
                },
                child: Text(
                  "Tidak, aku aman.",
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: Colors.grey),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jaga/core/theme/app_colors.dart';
import 'package:jaga/features/map/application/emergency_service.dart';

class PoliceNotifiedDialog extends ConsumerWidget {
  final String policeStationName;

  const PoliceNotifiedDialog({super.key, required this.policeStationName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.local_police_rounded,
              size: 80,
              color: AppColors.primary,
            ),
            const SizedBox(height: 16),

            Text(
              "Menginformasikan polisi terdekat",
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            Text(
              "Kami telah menginformasikan kantor polisi $policeStationName terkait situasimu.",
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Acknowledge Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text("Mengerti"),
              ),
            ),
            const SizedBox(height: 12),
            // Cancel Button
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
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Status darurat dibatalkan.",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                },
                child: Text(
                  "Batalkan, aku aman.",
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

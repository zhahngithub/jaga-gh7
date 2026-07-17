import 'package:flutter/material.dart';
import 'package:jaga/core/theme/app_colors.dart';

class HelpRequestDialog extends StatelessWidget {
  final int distanceInMeters;

  const HelpRequestDialog({super.key, required this.distanceInMeters});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sos_rounded, size: 80, color: AppColors.primary),
            const SizedBox(height: 16),

            Text(
              "Seseorang membutuhkan bantuanmu!",
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            Text(
              "Seorang pengguna $distanceInMeters meter dari kamu sedang dalam bahaya.",
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // TOOD: Can also show location once location is implemented
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
                  // TODO: Give the user in danger location
                  print("Opening victim's location...");
                },
                child: const Text("Lihat Lokasi"),
              ),
            ),
            const SizedBox(height: 12),

            // Dismiss Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Colors.grey),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text(
                  "Tutup",
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

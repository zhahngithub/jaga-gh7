import 'package:flutter/material.dart';
import 'package:jaga/core/theme/app_colors.dart';

class NearbyNotifiedDialog extends StatelessWidget {
  final int radiusInMeters;

  const NearbyNotifiedDialog({
    super.key,
    this.radiusInMeters = 500,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.notifications_active_rounded, size: 80, color: Colors.orange), 
            const SizedBox(height: 16),
            
            const Text(
              "Memberitahu pengguna sekitar!",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                height: 1.1,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            
            Text(
              "Seluruh pengguna di ${radiusInMeters}m sekitarmu telah diberitahu keadaan daruratmu.",
              style: const TextStyle(
                fontSize: 16, 
                color: Colors.grey,
                height: 1.2,
              ),
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
                child: const Text(
                  "Mengerti",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
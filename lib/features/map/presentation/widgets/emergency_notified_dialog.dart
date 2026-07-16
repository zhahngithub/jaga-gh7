import 'package:flutter/material.dart';
import 'package:jaga/core/theme/app_colors.dart';

class EmergencyNotifiedDialog extends StatelessWidget {
  const EmergencyNotifiedDialog({super.key});

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
            // Phone ringing icon
            const Icon(Icons.phone_in_talk_rounded, size: 80, color: Colors.orange), 
            const SizedBox(height: 16),
            
            const Text(
              "Notifying emergency contact",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                height: 1.1,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            
            const Text(
              "We've sent a message to notify your emergency contact.",
              style: TextStyle(
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
                  "Mengerti", // "Understood"
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
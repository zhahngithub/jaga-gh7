import 'package:flutter/material.dart';
import 'package:jaga/core/theme/app_colors.dart';

class SafetyCheckDialog extends StatelessWidget {
  final int distanceInMeters;
  

  const SafetyCheckDialog({
    super.key, 
    required this.distanceInMeters,
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
            // Warning Icon using the system's error color (defaults to red)
            Icon(Icons.warning_amber_rounded, size: 80, color: Colors.red), 
            const SizedBox(height: 16),
            
            const Text(
              "Apakah kamu aman?",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                height: 1.1,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            
            Text(
              "Kamu $distanceInMeters meter diluar jalur utama.",
              style: const TextStyle(
                fontSize: 16, 
                color: Colors.grey,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Emergency Button (Red / Solid)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.red, // Danger color
                  foregroundColor: Colors.white, // Text color
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  // TODO: Trigger emergency protocol (e.g., call API, notify contacts)
                  print("Emergency triggered!");
                },
                child: const Text(
                  "Tidak, aku dalam bahaya!", 
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 12), // Space between buttons

            // Safe Button (Outlined / Secondary)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: Colors.grey), // Blue border
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  // TODO: Dismiss alert and optionally recalculate route
                  print("User is safe.");
                },
                child: Text(
                  "Iya, aku aman.", 
                  style: TextStyle(
                    fontSize: 16, 
                    fontWeight: FontWeight.bold,
                    color: Colors.grey, // Blue text
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
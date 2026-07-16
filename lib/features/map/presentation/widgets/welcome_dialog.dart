import 'package:flutter/material.dart';
import 'package:jaga/core/theme/app_colors.dart';

class WelcomeDialog extends StatelessWidget {
  final String username;

  // This is the equivalent of passing "props" in React
  const WelcomeDialog({super.key, required this.username});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Hug contents vertically
          children: [
            // Replace with your actual image asset later (e.g., Image.asset('assets/welcome.png'))
            const Icon(Icons.shield_outlined, size: 80, color: Colors.blue), 
            const SizedBox(height: 16),
            Text(
              "Hai, $username!",
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 1),
            const Text(
              "Yuk capai destinasimu dengan aman!",
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity, // Full-width button
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
                  // This is how you close the pop-up
                  Navigator.of(context).pop(); 
                },
                child: const Text("Mulai", style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
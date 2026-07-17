import 'package:flutter/material.dart';
import 'package:jaga/core/theme/app_colors.dart';

class PinVerificationDialog extends StatefulWidget {
  final VoidCallback onSuccess;

  const PinVerificationDialog({super.key, required this.onSuccess});

  @override
  State<PinVerificationDialog> createState() => _PinVerificationDialogState();
}

class _PinVerificationDialogState extends State<PinVerificationDialog> {
  final TextEditingController _pinController = TextEditingController();
  String? _errorMessage;

  void _verifyPin() {
    // TODO: Replace '1234' with the actual user's
    const String correctPin = "1234"; 

    if (_pinController.text == correctPin) {
      widget.onSuccess();
    } else {
      setState(() {
        _errorMessage = "PIN salah.";
        _pinController.clear();
        Navigator.of(context).pop();
      });
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline_rounded, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            
            Text(
              "Masukkan PIN Keamanan",
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            
            Text(
              "Masukkan PIN kamu untuk membatalkan status darurat.",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // PIN Input Field
            TextField(
              controller: _pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 8.0),
              decoration: InputDecoration(
                counterText: "",
                errorText: _errorMessage,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Verify Button
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
                  if (_pinController.text.length == 4) {
                    _verifyPin();
                  }
                },
                child: Text(
                  "Verifikasi",
                ),
              ),
            ),
            const SizedBox(height: 6),

            // Back Button
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  "Kembali", 
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.grey),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
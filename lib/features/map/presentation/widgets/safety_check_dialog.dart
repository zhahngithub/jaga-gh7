import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jaga/core/theme/app_colors.dart';
import 'package:jaga/features/map/application/emergency_service.dart';
import 'package:jaga/features/map/presentation/widgets/pin_verification_dialog.dart';

class SafetyCheckDialog extends ConsumerStatefulWidget {
  final int distanceInMeters;

  const SafetyCheckDialog({super.key, required this.distanceInMeters});

  @override
  ConsumerState<SafetyCheckDialog> createState() => _SafetyCheckDialogState();
}

class _SafetyCheckDialogState extends ConsumerState<SafetyCheckDialog> {
  bool _isVerifyingPin = false;

  Future<void> _markAsSafe() async {
    if (_isVerifyingPin) return;
    setState(() => _isVerifyingPin = true);

    final verified = await showPinVerificationDialog(
      context,
      reason: 'membatalkan peringatan darurat',
    );
    if (!mounted) return;
    if (!verified) {
      setState(() => _isVerifyingPin = false);
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    ref.read(emergencyProvider.notifier).markAsSafe();
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Status darurat berhasil dibatalkan.',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final emergencyState = ref.watch(emergencyProvider);
    final distance =
        emergencyState.offTrackDistanceMeters ?? widget.distanceInMeters;
    final seconds = emergencyState.secondsRemaining ?? 0;

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
              'Kamu $distance meter di luar jalur utama. Jika tidak ada '
              'respons, kontak daruratmu akan dihubungi dalam $seconds detik.',
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
                onPressed: _isVerifyingPin ? null : _markAsSafe,
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

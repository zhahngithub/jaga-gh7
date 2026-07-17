import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jaga/core/theme/app_colors.dart';
import 'package:jaga/features/map/application/emergency_service.dart';
import 'package:jaga/features/map/presentation/widgets/pin_verification_dialog.dart';

class NearbyNotifiedDialog extends ConsumerStatefulWidget {
  final int radiusInMeters;

  const NearbyNotifiedDialog({super.key, this.radiusInMeters = 500});

  @override
  ConsumerState<NearbyNotifiedDialog> createState() =>
      _NearbyNotifiedDialogState();
}

class _NearbyNotifiedDialogState extends ConsumerState<NearbyNotifiedDialog> {
  bool _isVerifyingPin = false;

  Future<void> _cancelEmergency() async {
    if (_isVerifyingPin) return;
    setState(() => _isVerifyingPin = true);

    final verified = await showPinVerificationDialog(context);
    if (!mounted) return;
    if (!verified) {
      setState(() => _isVerifyingPin = false);
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    ref.read(emergencyProvider.notifier).markAsSafe();
    Navigator.of(context).pop();
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
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.notifications_active_rounded,
              size: 80,
              color: AppColors.primary,
            ),
            const SizedBox(height: 16),

            Text(
              "Memberitahu pengguna sekitar!",
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            Text(
              "Seluruh pengguna di ${widget.radiusInMeters}m sekitarmu telah diberitahu keadaan daruratmu.",
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
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
                onPressed: _isVerifyingPin ? null : _cancelEmergency,
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

import 'package:flutter/material.dart';

import 'screens/pin_verification_screen.dart';

/// Requests local PIN confirmation before a caller performs a protected action.
///
/// Example: `if (!await requirePinVerification(context, reason: 'melanjutkan tindakan')) return;`
Future<bool> requirePinVerification(
  BuildContext context, {
  required String reason,
  String title = 'Verifikasi PIN',
  String description = 'Masukkan PIN keamanan untuk melanjutkan.',
  String confirmButtonLabel = 'Verifikasi',
}) async {
  if (!context.mounted) {
    return false;
  }
  final result = await Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(
      builder: (_) => PinVerificationScreen(
        title: title,
        description: description,
        reason: reason,
        confirmButtonLabel: confirmButtonLabel,
      ),
    ),
  );
  return result == true;
}

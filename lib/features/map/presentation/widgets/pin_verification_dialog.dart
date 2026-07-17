import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jaga/core/theme/app_colors.dart';
import 'package:jaga/features/pin/application/pin_providers.dart';
import 'package:jaga/features/pin/application/pin_validation.dart';
import 'package:jaga/features/pin/application/pin_verification_controller.dart';
import 'package:jaga/features/pin/presentation/widgets/pin_input_field.dart';

Future<bool> showPinVerificationDialog(
  BuildContext context, {
  String reason = 'membatalkan status darurat',
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PinVerificationDialog(reason: reason),
  );
  return result == true;
}

class PinVerificationDialog extends ConsumerStatefulWidget {
  const PinVerificationDialog({
    this.reason = 'membatalkan status darurat',
    super.key,
  });

  final String reason;

  @override
  ConsumerState<PinVerificationDialog> createState() =>
      _PinVerificationDialogState();
}

class _PinVerificationDialogState extends ConsumerState<PinVerificationDialog> {
  final _pinController = TextEditingController();
  final _pinFocusNode = FocusNode();

  Timer? _lockoutTimer;
  String? _pinError;
  DateTime? _lockoutUntil;
  int _remainingSeconds = 0;

  String? get _uid => ref.read(currentPinUserIdProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _inspectAttempts());
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    _pinController.clear();
    _pinController.dispose();
    _pinFocusNode.dispose();
    super.dispose();
  }

  Future<void> _inspectAttempts() async {
    ref.read(pinVerificationControllerProvider.notifier).clearMessage();
    final attempts = await ref
        .read(pinVerificationControllerProvider.notifier)
        .inspectAttempts(_uid);
    if (!mounted || attempts == null) {
      return;
    }
    _startLockoutTimer(attempts.lockoutUntil);
    if (_remainingSeconds == 0) {
      _pinFocusNode.requestFocus();
    }
  }

  Future<void> _verifyPin() async {
    final request = ref.read(pinVerificationControllerProvider);
    if (request.isLoading || _remainingSeconds > 0) {
      return;
    }

    FocusScope.of(context).unfocus();
    final pin = _pinController.text;
    final pinError = validatePinForVerification(pin);
    setState(() => _pinError = pinError);
    if (pinError != null) {
      return;
    }

    final outcome = await ref
        .read(pinVerificationControllerProvider.notifier)
        .verify(uid: _uid, pin: pin);
    if (!mounted) {
      return;
    }

    _pinController.clear();
    if (outcome.verified) {
      Navigator.of(context).pop(true);
      return;
    }

    _startLockoutTimer(outcome.lockoutUntil);
    if (_remainingSeconds == 0) {
      _pinFocusNode.requestFocus();
    }
  }

  void _startLockoutTimer(DateTime? lockoutUntil) {
    _lockoutTimer?.cancel();
    _lockoutUntil = lockoutUntil;
    if (lockoutUntil == null) {
      setState(() => _remainingSeconds = 0);
      return;
    }
    _updateRemainingLockout();
    if (_remainingSeconds == 0) {
      return;
    }
    _lockoutTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateRemainingLockout(),
    );
  }

  void _updateRemainingLockout() {
    final until = _lockoutUntil;
    final milliseconds = until?.difference(DateTime.now()).inMilliseconds ?? 0;
    final seconds = milliseconds <= 0 ? 0 : (milliseconds / 1000).ceil();
    if (!mounted) {
      return;
    }
    setState(() => _remainingSeconds = seconds);
    if (seconds == 0) {
      _lockoutTimer?.cancel();
      _lockoutUntil = null;
      ref.read(pinVerificationControllerProvider.notifier).clearMessage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = ref.watch(pinVerificationControllerProvider);
    final isLocked = _remainingSeconds > 0;
    final isBusy = request.isLoading || isLocked;
    final isPinComplete = _pinController.text.length == 4;
    final errorMessage = isLocked
        ? 'Terlalu banyak percobaan. Coba lagi dalam $_remainingSeconds detik.'
        : request.errorMessage;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.lock_outline_rounded,
              size: 48,
              color: AppColors.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'Masukkan PIN keamanan',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              widget.reason == 'membatalkan status darurat'
                  ? 'Masukkan PIN kamu untuk membatalkan status darurat.'
                  : 'Masukkan PIN kamu untuk ${widget.reason}.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            PinInputField(
              controller: _pinController,
              focusNode: _pinFocusNode,
              semanticLabel: 'Masukkan PIN 4 digit',
              enabled: !isBusy,
              errorText: _pinError,
              textInputAction: TextInputAction.done,
              onChanged: (_) {
                setState(() => _pinError = null);
                ref
                    .read(pinVerificationControllerProvider.notifier)
                    .clearMessage();
              },
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                errorMessage,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              height: 50,
              child: FilledButton(
                onPressed: isBusy || !isPinComplete ? null : _verifyPin,
                child: request.isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Verifikasi'),
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: request.isLoading
                  ? null
                  : () => Navigator.of(context).pop(false),
              child: const Text('Kembali'),
            ),
          ],
        ),
      ),
    );
  }
}

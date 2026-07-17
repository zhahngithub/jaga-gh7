import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/widgets/auth_form_widgets.dart';
import '../../../auth/presentation/widgets/auth_page_scaffold.dart';
import '../../application/pin_validation.dart';
import '../../application/pin_verification_controller.dart';
import '../../application/pin_providers.dart';
import '../widgets/pin_input_field.dart';

class PinVerificationScreen extends ConsumerStatefulWidget {
  const PinVerificationScreen({
    required this.reason,
    this.title = 'Verifikasi PIN',
    this.description = 'Masukkan PIN keamanan untuk melanjutkan.',
    this.confirmButtonLabel = 'Verifikasi',
    super.key,
  });

  final String title;
  final String description;
  final String reason;
  final String confirmButtonLabel;

  @override
  ConsumerState<PinVerificationScreen> createState() =>
      _PinVerificationScreenState();
}

class _PinVerificationScreenState extends ConsumerState<PinVerificationScreen> {
  final _pinController = TextEditingController();
  final _pinFocusNode = FocusNode();

  Timer? _lockoutTimer;
  String? _pinError;
  DateTime? _lockoutUntil;
  int _remainingSeconds = 0;

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

  String? get _uid => ref.read(currentPinUserIdProvider);

  Future<void> _inspectAttempts() async {
    ref.read(pinVerificationControllerProvider.notifier).clearMessage();
    final attempts = await ref
        .read(pinVerificationControllerProvider.notifier)
        .inspectAttempts(_uid);
    if (!mounted || attempts == null) {
      return;
    }
    _startLockoutTimer(attempts.lockoutUntil);
  }

  Future<void> _submit() async {
    if (_remainingSeconds > 0) {
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
    final errorMessage = isLocked
        ? 'Terlalu banyak percobaan. Coba lagi dalam $_remainingSeconds detik.'
        : request.errorMessage;

    return AuthPageScaffold(
      leading: const AuthBackButton(),
      title: widget.title,
      subtitle: widget.description,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF6FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.shield_outlined, size: 21),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Konfirmasi diperlukan untuk ${widget.reason}.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Masukkan PIN 4 digit',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 9),
          PinInputField(
            controller: _pinController,
            focusNode: _pinFocusNode,
            semanticLabel: 'Masukkan PIN 4 digit',
            enabled: !isBusy,
            errorText: _pinError,
            textInputAction: TextInputAction.done,
            onChanged: (_) {
              if (_pinError != null) {
                setState(() => _pinError = null);
              }
              ref
                  .read(pinVerificationControllerProvider.notifier)
                  .clearMessage();
            },
            onCompleted: (_) => _submit(),
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 18),
            RequestMessageContainer(errorMessage: errorMessage),
          ],
          const SizedBox(height: 22),
          AuthPrimaryButton(
            label: widget.confirmButtonLabel,
            isLoading: request.isLoading,
            onPressed: isBusy ? null : _submit,
          ),
        ],
      ),
    );
  }
}

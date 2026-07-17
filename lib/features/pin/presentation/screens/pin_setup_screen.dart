import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/widgets/auth_form_widgets.dart';
import '../../../auth/presentation/widgets/auth_page_scaffold.dart';
import '../../application/pin_setup_controller.dart';
import '../../application/pin_validation.dart';
import '../widgets/pin_input_field.dart';

class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({required this.uid, required this.onSignOut, super.key});

  final String uid;
  final Future<bool> Function() onSignOut;

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  final _pinController = TextEditingController();
  final _confirmationController = TextEditingController();
  final _pinFocusNode = FocusNode();
  final _confirmationFocusNode = FocusNode();

  String? _pinError;
  String? _confirmationError;
  String? _signOutError;
  bool _isSigningOut = false;

  @override
  void dispose() {
    _clearSensitiveInputs();
    _pinController.dispose();
    _confirmationController.dispose();
    _pinFocusNode.dispose();
    _confirmationFocusNode.dispose();
    super.dispose();
  }

  void _clearSensitiveInputs() {
    _pinController.clear();
    _confirmationController.clear();
  }

  void _clearFeedback() {
    ref.read(pinSetupControllerProvider.notifier).clearMessage();
    if (_signOutError != null) {
      setState(() => _signOutError = null);
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final pin = _pinController.text;
    final confirmation = _confirmationController.text;
    final pinError = validatePin(pin);
    final confirmationError = validatePinConfirmation(
      pin: pin,
      confirmation: confirmation,
    );

    setState(() {
      _pinError = pinError;
      _confirmationError = confirmationError;
      _signOutError = null;
    });
    if (pinError != null || confirmationError != null) {
      return;
    }

    final outcome = await ref
        .read(pinSetupControllerProvider.notifier)
        .setInitialPin(uid: widget.uid, pin: pin, confirmation: confirmation);
    if (!mounted) {
      return;
    }
    if (outcome == PinSetupOutcome.success) {
      _clearSensitiveInputs();
    }
  }

  Future<void> _signOut() async {
    if (_isSigningOut) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _isSigningOut = true;
      _signOutError = null;
    });
    final succeeded = await widget.onSignOut();
    if (!mounted) {
      return;
    }
    if (succeeded) {
      _clearSensitiveInputs();
      return;
    }
    setState(() {
      _isSigningOut = false;
      _signOutError = 'Akun belum dapat dikeluarkan. Silakan coba lagi.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final request = ref.watch(pinSetupControllerProvider);
    final isBusy = request.isLoading || _isSigningOut;

    return AuthPageScaffold(
      trailing: TextButton.icon(
        onPressed: isBusy ? null : _signOut,
        icon: _isSigningOut
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.logout_rounded),
        label: const Text('Keluar'),
      ),
      title: 'Buat PIN keamanan',
      subtitle:
          'PIN ini disimpan secara aman di perangkat ini dan digunakan untuk mengonfirmasi tindakan di Jaga.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
            onChanged: (_) {
              if (_pinError != null) {
                setState(() => _pinError = null);
              }
              _clearFeedback();
            },
            onCompleted: (_) => _confirmationFocusNode.requestFocus(),
          ),
          const SizedBox(height: 20),
          Text('Konfirmasi PIN', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 9),
          PinInputField(
            controller: _confirmationController,
            focusNode: _confirmationFocusNode,
            semanticLabel: 'Konfirmasi PIN',
            enabled: !isBusy,
            errorText: _confirmationError,
            textInputAction: TextInputAction.done,
            onChanged: (_) {
              if (_confirmationError != null) {
                setState(() => _confirmationError = null);
              }
              _clearFeedback();
            },
          ),
          if (request.errorMessage != null || _signOutError != null) ...[
            const SizedBox(height: 18),
            RequestMessageContainer(
              errorMessage: request.errorMessage ?? _signOutError,
            ),
          ],
          const SizedBox(height: 22),
          AuthPrimaryButton(
            label: 'Simpan PIN',
            isLoading: request.isLoading,
            onPressed: isBusy ? null : _submit,
          ),
        ],
      ),
    );
  }
}

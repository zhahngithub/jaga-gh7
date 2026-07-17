import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/request_state.dart';
import '../data/models/pin_models.dart';
import 'pin_error_mapper.dart';
import 'pin_providers.dart';
import 'pin_validation.dart';

final pinSetupControllerProvider =
    NotifierProvider<PinSetupController, RequestState>(PinSetupController.new);

enum PinSetupOutcome { success, recoverableFailure, ignored }

class PinSetupController extends Notifier<RequestState> {
  @override
  RequestState build() => RequestState.idle;

  Future<PinSetupOutcome> setInitialPin({
    required String uid,
    required String pin,
    required String confirmation,
  }) async {
    if (state.isLoading) {
      return PinSetupOutcome.ignored;
    }

    final pinError = validatePin(pin);
    final confirmationError = validatePinConfirmation(
      pin: pin,
      confirmation: confirmation,
    );
    if (pinError != null || confirmationError != null) {
      state = RequestState.error(pinError ?? confirmationError!);
      return PinSetupOutcome.recoverableFailure;
    }

    state = RequestState.loading;
    try {
      await ref.read(pinRepositoryProvider).setInitialPin(uid, pin);
      ref.invalidate(pinStatusProvider(uid));
      state = RequestState.idle;
      return PinSetupOutcome.success;
    } on PinFailure catch (failure) {
      state = RequestState.error(
        mapPinFailure(failure, operation: PinOperation.setup),
      );
      return PinSetupOutcome.recoverableFailure;
    } on Object {
      state = RequestState.error(
        mapPinFailure(
          const PinFailure(PinErrorCode.unknown),
          operation: PinOperation.setup,
        ),
      );
      return PinSetupOutcome.recoverableFailure;
    }
  }

  void clearMessage() {
    if (!state.isLoading) {
      state = RequestState.idle;
    }
  }
}

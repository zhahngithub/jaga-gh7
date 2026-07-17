import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/request_state.dart';
import '../data/models/pin_models.dart';
import 'pin_error_mapper.dart';
import 'pin_providers.dart';

final pinVerificationControllerProvider =
    NotifierProvider<PinVerificationController, RequestState>(
      PinVerificationController.new,
    );

class PinVerificationOutcome {
  const PinVerificationOutcome({required this.verified, this.lockoutUntil});

  final bool verified;
  final DateTime? lockoutUntil;
}

class PinVerificationController extends Notifier<RequestState> {
  @override
  RequestState build() => RequestState.idle;

  Future<PinAttemptState?> inspectAttempts(String? uid) async {
    try {
      if (uid == null || uid.isEmpty) {
        throw const PinFailure(PinErrorCode.noAuthenticatedUid);
      }
      return await ref.read(pinRepositoryProvider).getAttemptState(uid);
    } on PinFailure catch (failure) {
      state = RequestState.error(
        mapPinFailure(failure, operation: PinOperation.verification),
      );
      return null;
    } on Object {
      state = RequestState.error(
        mapPinFailure(
          const PinFailure(PinErrorCode.unknown),
          operation: PinOperation.verification,
        ),
      );
      return null;
    }
  }

  Future<PinVerificationOutcome> verify({
    required String? uid,
    required String pin,
  }) async {
    if (state.isLoading) {
      return const PinVerificationOutcome(verified: false);
    }

    state = RequestState.loading;
    try {
      if (uid == null || uid.isEmpty) {
        throw const PinFailure(PinErrorCode.noAuthenticatedUid);
      }
      final verified = await ref
          .read(pinRepositoryProvider)
          .verifyPin(uid, pin);
      state = RequestState.idle;
      return PinVerificationOutcome(verified: verified);
    } on PinFailure catch (failure) {
      state = RequestState.error(
        mapPinFailure(failure, operation: PinOperation.verification),
      );
      return PinVerificationOutcome(
        verified: false,
        lockoutUntil: failure.lockoutUntil,
      );
    } on Object {
      state = RequestState.error(
        mapPinFailure(
          const PinFailure(PinErrorCode.unknown),
          operation: PinOperation.verification,
        ),
      );
      return const PinVerificationOutcome(verified: false);
    }
  }

  void clearMessage() {
    if (!state.isLoading) {
      state = RequestState.idle;
    }
  }
}

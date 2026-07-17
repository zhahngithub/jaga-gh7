enum PinErrorCode {
  noAuthenticatedUid,
  pinNotConfigured,
  invalidPin,
  weakPin,
  incorrectPin,
  temporaryLockout,
  storageReadFailure,
  storageWriteFailure,
  cryptographyFailure,
  alreadyConfigured,
  unknown,
}

class PinFailure implements Exception {
  const PinFailure(this.code, {this.lockoutUntil});

  final PinErrorCode code;
  final DateTime? lockoutUntil;
}

class PinAttemptState {
  const PinAttemptState({required this.failedAttempts, this.lockoutUntil});

  final int failedAttempts;
  final DateTime? lockoutUntil;

  bool isLockedAt(DateTime time) => lockoutUntil?.isAfter(time) ?? false;

  Duration remainingAt(DateTime time) {
    final until = lockoutUntil;
    if (until == null || !until.isAfter(time)) {
      return Duration.zero;
    }
    return until.difference(time);
  }
}

class PinSecretData {
  const PinSecretData({required this.encodedHash, required this.encodedSalt});

  final String encodedHash;
  final String encodedSalt;
}

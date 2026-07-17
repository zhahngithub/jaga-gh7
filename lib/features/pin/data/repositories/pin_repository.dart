import '../models/pin_models.dart';
import '../models/pin_rules.dart';
import 'pin_cryptography.dart';
import 'secure_key_value_store.dart';

abstract interface class PinRepository {
  Future<bool> hasPin(String uid);

  Future<void> setInitialPin(String uid, String pin);

  Future<bool> verifyPin(String uid, String pin);

  Future<PinAttemptState> getAttemptState(String uid);

  Future<void> clearPin(String uid);
}

class LocalPinRepository implements PinRepository {
  LocalPinRepository(
    this._storage, {
    PinCryptography? cryptography,
    DateTime Function()? now,
  }) : _cryptography = cryptography ?? Pbkdf2PinCryptography(),
       _now = now ?? DateTime.now;

  static const algorithmVersion = '1';
  static const algorithmName = 'pbkdf2-hmac-sha256';
  static const iterationCount = 120000;
  static const maxFailedAttempts = 5;
  static const lockoutDuration = Duration(seconds: 30);

  final SecureKeyValueStore _storage;
  final PinCryptography _cryptography;
  final DateTime Function() _now;

  @override
  Future<bool> hasPin(String uid) async {
    _ensureUid(uid);
    final record = await _readRecord(uid);
    return record != null;
  }

  @override
  Future<void> setInitialPin(String uid, String pin) async {
    _ensureUid(uid);
    _ensurePinCanBeCreated(pin);
    if (await hasPin(uid)) {
      throw const PinFailure(PinErrorCode.alreadyConfigured);
    }

    late final PinSecretData secret;
    try {
      secret = await _cryptography.createSecret(pin);
    } on Object {
      throw const PinFailure(PinErrorCode.cryptographyFailure);
    }

    final keys = _PinKeys(uid);
    await _write(keys.version, algorithmVersion);
    await _write(keys.algorithm, algorithmName);
    await _write(keys.iterations, iterationCount.toString());
    await _write(keys.salt, secret.encodedSalt);
    await _write(keys.hash, secret.encodedHash);
    await _clearAttemptState(keys);
  }

  @override
  Future<bool> verifyPin(String uid, String pin) async {
    _ensureUid(uid);
    if (!isFourDigitPin(pin)) {
      throw const PinFailure(PinErrorCode.invalidPin);
    }

    final keys = _PinKeys(uid);
    final record = await _readRecord(uid);
    if (record == null) {
      throw const PinFailure(PinErrorCode.pinNotConfigured);
    }

    final attempts = await getAttemptState(uid);
    final now = _now();
    if (attempts.isLockedAt(now)) {
      throw PinFailure(
        PinErrorCode.temporaryLockout,
        lockoutUntil: attempts.lockoutUntil,
      );
    }

    late final bool verified;
    try {
      verified = await _cryptography.verify(
        pin: pin,
        encodedSalt: record.encodedSalt,
        encodedHash: record.encodedHash,
        iterations: record.iterations,
      );
    } on Object {
      throw const PinFailure(PinErrorCode.cryptographyFailure);
    }

    if (verified) {
      await _clearAttemptState(keys);
      return true;
    }

    final failedAttempts = attempts.failedAttempts + 1;
    if (failedAttempts >= maxFailedAttempts) {
      final lockoutUntil = now.add(lockoutDuration);
      await _write(keys.failedAttempts, failedAttempts.toString());
      await _write(
        keys.lockoutUntil,
        lockoutUntil.millisecondsSinceEpoch.toString(),
      );
      throw PinFailure(
        PinErrorCode.temporaryLockout,
        lockoutUntil: lockoutUntil,
      );
    }

    await _write(keys.failedAttempts, failedAttempts.toString());
    throw const PinFailure(PinErrorCode.incorrectPin);
  }

  @override
  Future<PinAttemptState> getAttemptState(String uid) async {
    _ensureUid(uid);
    final keys = _PinKeys(uid);
    final failedAttempts =
        int.tryParse(await _read(keys.failedAttempts) ?? '') ?? 0;
    final lockoutMilliseconds = int.tryParse(
      await _read(keys.lockoutUntil) ?? '',
    );
    final lockoutUntil = lockoutMilliseconds == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(lockoutMilliseconds);

    if (lockoutUntil != null && !lockoutUntil.isAfter(_now())) {
      await _clearAttemptState(keys);
      return const PinAttemptState(failedAttempts: 0);
    }

    return PinAttemptState(
      failedAttempts: failedAttempts,
      lockoutUntil: lockoutUntil,
    );
  }

  @override
  Future<void> clearPin(String uid) async {
    _ensureUid(uid);
    final keys = _PinKeys(uid);
    for (final key in keys.all) {
      await _delete(key);
    }
  }

  Future<_PinRecord?> _readRecord(String uid) async {
    final keys = _PinKeys(uid);
    final version = await _read(keys.version);
    final algorithm = await _read(keys.algorithm);
    final iterations = int.tryParse(await _read(keys.iterations) ?? '');
    final encodedSalt = await _read(keys.salt);
    final encodedHash = await _read(keys.hash);
    if (version == null ||
        algorithm == null ||
        iterations == null ||
        encodedSalt == null ||
        encodedHash == null) {
      return null;
    }
    if (version != algorithmVersion ||
        algorithm != algorithmName ||
        iterations < 100000) {
      throw const PinFailure(PinErrorCode.cryptographyFailure);
    }
    return _PinRecord(
      encodedHash: encodedHash,
      encodedSalt: encodedSalt,
      iterations: iterations,
    );
  }

  void _ensureUid(String uid) {
    if (uid.trim().isEmpty) {
      throw const PinFailure(PinErrorCode.noAuthenticatedUid);
    }
  }

  void _ensurePinCanBeCreated(String pin) {
    if (!isFourDigitPin(pin)) {
      throw const PinFailure(PinErrorCode.invalidPin);
    }
    if (isWeakPin(pin)) {
      throw const PinFailure(PinErrorCode.weakPin);
    }
  }

  Future<String?> _read(String key) async {
    try {
      return await _storage.read(key);
    } on Object {
      throw const PinFailure(PinErrorCode.storageReadFailure);
    }
  }

  Future<void> _write(String key, String value) async {
    try {
      await _storage.write(key, value);
    } on Object {
      throw const PinFailure(PinErrorCode.storageWriteFailure);
    }
  }

  Future<void> _delete(String key) async {
    try {
      await _storage.delete(key);
    } on Object {
      throw const PinFailure(PinErrorCode.storageWriteFailure);
    }
  }

  Future<void> _clearAttemptState(_PinKeys keys) async {
    await _delete(keys.failedAttempts);
    await _delete(keys.lockoutUntil);
  }
}

class _PinRecord {
  const _PinRecord({
    required this.encodedHash,
    required this.encodedSalt,
    required this.iterations,
  });

  final String encodedHash;
  final String encodedSalt;
  final int iterations;
}

class _PinKeys {
  _PinKeys(String uid) : prefix = 'jaga.pin.v1.$uid';

  final String prefix;

  String get hash => '$prefix.hash';
  String get salt => '$prefix.salt';
  String get version => '$prefix.version';
  String get algorithm => '$prefix.algorithm';
  String get iterations => '$prefix.iterations';
  String get failedAttempts => '$prefix.failedAttempts';
  String get lockoutUntil => '$prefix.lockoutUntil';

  List<String> get all => <String>[
    hash,
    salt,
    version,
    algorithm,
    iterations,
    failedAttempts,
    lockoutUntil,
  ];
}

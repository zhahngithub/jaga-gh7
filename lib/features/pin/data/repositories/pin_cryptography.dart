import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/helpers.dart';

import '../models/pin_models.dart';

abstract interface class PinCryptography {
  Future<PinSecretData> createSecret(String pin);

  Future<bool> verify({
    required String pin,
    required String encodedSalt,
    required String encodedHash,
    required int iterations,
  });
}

class Pbkdf2PinCryptography implements PinCryptography {
  static const saltLength = 16;
  static const hashLength = 32;

  @override
  Future<PinSecretData> createSecret(String pin) async {
    final salt = randomBytes(saltLength);
    final hash = await _derive(pin: pin, salt: salt, iterations: 120000);
    return PinSecretData(
      encodedHash: base64Encode(hash),
      encodedSalt: base64Encode(salt),
    );
  }

  @override
  Future<bool> verify({
    required String pin,
    required String encodedSalt,
    required String encodedHash,
    required int iterations,
  }) async {
    final salt = base64Decode(encodedSalt);
    final expectedHash = base64Decode(encodedHash);
    if (salt.length != saltLength || expectedHash.length != hashLength) {
      throw const FormatException('Invalid local PIN record.');
    }

    final actualHash = await _derive(
      pin: pin,
      salt: salt,
      iterations: iterations,
    );
    return constantTimeBytesEquality.equals(actualHash, expectedHash);
  }

  Future<List<int>> _derive({
    required String pin,
    required List<int> salt,
    required int iterations,
  }) async {
    final algorithm = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: hashLength * 8,
    );
    final key = await algorithm.deriveKeyFromPassword(
      password: pin,
      nonce: salt,
    );
    return key.extractBytes();
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jaga/features/auth/data/models/user_profile.dart';
import 'package:jaga/features/pin/application/pin_error_mapper.dart';
import 'package:jaga/features/pin/application/pin_providers.dart';
import 'package:jaga/features/pin/application/pin_validation.dart';
import 'package:jaga/features/pin/data/models/pin_models.dart';
import 'package:jaga/features/pin/data/repositories/pin_repository.dart';
import 'package:jaga/features/pin/data/repositories/secure_key_value_store.dart';

void main() {
  group('validasi PIN', () {
    test('menerima PIN empat digit yang tidak mudah ditebak', () {
      expect(validatePin('4827'), isNull);
    });

    test('menolak karakter non-numerik', () {
      expect(validatePin('12a4'), 'PIN harus terdiri dari 4 angka.');
    });

    test('menolak PIN terlalu pendek dan terlalu panjang', () {
      expect(validatePin('123'), 'PIN harus terdiri dari 4 angka.');
      expect(validatePin('12345'), 'PIN harus terdiri dari 4 angka.');
    });

    test('menolak PIN dengan digit berulang', () {
      for (final pin in <String>[
        '0000',
        '1111',
        '2222',
        '3333',
        '4444',
        '5555',
        '6666',
        '7777',
        '8888',
        '9999',
      ]) {
        expect(validatePin(pin), 'Gunakan PIN yang tidak mudah ditebak.');
      }
    });

    test('menolak 1234 dan 4321', () {
      expect(validatePin('1234'), 'Gunakan PIN yang tidak mudah ditebak.');
      expect(validatePin('4321'), 'Gunakan PIN yang tidak mudah ditebak.');
    });

    test('menerima konfirmasi yang cocok', () {
      expect(
        validatePinConfirmation(pin: '4827', confirmation: '4827'),
        isNull,
      );
    });

    test('menolak konfirmasi yang berbeda', () {
      expect(
        validatePinConfirmation(pin: '4827', confirmation: '4826'),
        'Konfirmasi PIN tidak sesuai.',
      );
    });
  });

  group('repository PIN lokal', () {
    late InMemorySecureKeyValueStore storage;
    late LocalPinRepository repository;
    late DateTime now;

    setUp(() {
      storage = InMemorySecureKeyValueStore();
      now = DateTime.utc(2026, 7, 17, 10);
      repository = LocalPinRepository(storage, now: () => now);
    });

    test('hasPin berubah dari false menjadi true setelah setup', () async {
      expect(await repository.hasPin('uid-a'), isFalse);

      await repository.setInitialPin('uid-a', '4827');

      expect(await repository.hasPin('uid-a'), isTrue);
      expect(
        storage.values.keys,
        everyElement(startsWith('jaga.pin.v1.uid-a.')),
      );
    });

    test('setup tidak menyimpan PIN plaintext', () async {
      await repository.setInitialPin('uid-a', '4827');

      expect(storage.values.values, isNot(contains('4827')));
      expect(storage.values.keys, isNot(contains('jaga.pin.v1.uid-a.pin')));
    });

    test('PIN yang benar dapat diverifikasi', () async {
      await repository.setInitialPin('uid-a', '4827');

      expect(await repository.verifyPin('uid-a', '4827'), isTrue);
    });

    test('PIN yang salah ditolak dan percobaan bertambah', () async {
      await repository.setInitialPin('uid-a', '4827');

      await _expectPinFailure(
        () => repository.verifyPin('uid-a', '4826'),
        PinErrorCode.incorrectPin,
      );
      final attempts = await repository.getAttemptState('uid-a');
      expect(attempts.failedAttempts, 1);
    });

    test('UID berbeda tidak dapat menggunakan PIN UID lain', () async {
      await repository.setInitialPin('uid-a', '4827');

      expect(await repository.hasPin('uid-b'), isFalse);
      await _expectPinFailure(
        () => repository.verifyPin('uid-b', '4827'),
        PinErrorCode.pinNotConfigured,
      );
    });

    test('lima kegagalan memicu lockout sementara', () async {
      await repository.setInitialPin('uid-a', '4827');

      for (var attempt = 1; attempt <= 4; attempt++) {
        await _expectPinFailure(
          () => repository.verifyPin('uid-a', '4826'),
          PinErrorCode.incorrectPin,
        );
      }
      await _expectPinFailure(
        () => repository.verifyPin('uid-a', '4826'),
        PinErrorCode.temporaryLockout,
      );

      final attempts = await repository.getAttemptState('uid-a');
      expect(attempts.failedAttempts, 5);
      expect(attempts.remainingAt(now), const Duration(seconds: 30));
      await _expectPinFailure(
        () => repository.verifyPin('uid-a', '4827'),
        PinErrorCode.temporaryLockout,
      );
    });

    test('lockout berakhir setelah tiga puluh detik', () async {
      await repository.setInitialPin('uid-a', '4827');
      for (var attempt = 1; attempt <= 5; attempt++) {
        try {
          await repository.verifyPin('uid-a', '4826');
        } on PinFailure {
          // Expected while building the local failed-attempt state.
        }
      }

      now = now.add(const Duration(seconds: 31));

      expect(await repository.verifyPin('uid-a', '4827'), isTrue);
    });

    test('verifikasi berhasil mereset percobaan gagal', () async {
      await repository.setInitialPin('uid-a', '4827');
      await _expectPinFailure(
        () => repository.verifyPin('uid-a', '4826'),
        PinErrorCode.incorrectPin,
      );

      expect(await repository.verifyPin('uid-a', '4827'), isTrue);
      final attempts = await repository.getAttemptState('uid-a');
      expect(attempts.failedAttempts, 0);
      expect(attempts.lockoutUntil, isNull);
    });
  });

  test(
    'pinStatusProvider membaca repository lokal dan dapat direfresh',
    () async {
      final storage = InMemorySecureKeyValueStore();
      final repository = LocalPinRepository(storage);
      final container = ProviderContainer(
        overrides: [pinRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      expect(await container.read(pinStatusProvider('uid-a').future), isFalse);
      await repository.setInitialPin('uid-a', '4827');
      container.invalidate(pinStatusProvider('uid-a'));
      expect(await container.read(pinStatusProvider('uid-a').future), isTrue);
    },
  );

  test('UserProfile mengabaikan field PIN Firestore lama', () {
    final profile = UserProfile.fromMap(
      uid: 'uid-legacy',
      map: <String, Object?>{
        'displayName': 'Nia',
        'email': 'nia@example.com',
        'phoneNumber': '+6281234567890',
        'photoUrl': null,
        'helperModeEnabled': false,
        'communityAssistanceEnabled': false,
        'pinConfigured': true,
        'pinSetAt': 'legacy-timestamp',
        'createdAt': 'created',
        'updatedAt': 'updated',
      },
    );

    expect(profile.displayName, 'Nia');
    expect(
      profile.toMap(createdAt: 'created', updatedAt: 'updated').keys,
      hasLength(8),
    );
  });

  group('pesan error lokal', () {
    test('menyembunyikan error penyimpanan dan kriptografi', () {
      expect(
        mapPinFailure(
          const PinFailure(PinErrorCode.storageReadFailure),
          operation: PinOperation.verification,
        ),
        'Penyimpanan aman perangkat tidak tersedia.',
      );
      expect(
        mapPinFailure(
          const PinFailure(PinErrorCode.cryptographyFailure),
          operation: PinOperation.verification,
        ),
        'PIN belum dapat diverifikasi. Coba lagi.',
      );
    });

    test('menampilkan pesan PIN salah yang ramah', () {
      expect(
        mapPinFailure(
          const PinFailure(PinErrorCode.incorrectPin),
          operation: PinOperation.verification,
        ),
        'PIN yang kamu masukkan salah.',
      );
    });
  });
}

Future<void> _expectPinFailure(
  Future<bool> Function() action,
  PinErrorCode expectedCode,
) async {
  try {
    await action();
    fail('Expected a PinFailure.');
  } on PinFailure catch (failure) {
    expect(failure.code, expectedCode);
  }
}

class InMemorySecureKeyValueStore implements SecureKeyValueStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

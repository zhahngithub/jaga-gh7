import 'package:flutter_test/flutter_test.dart';
import 'package:jaga/features/auth/application/auth_validators.dart';
import 'package:jaga/features/auth/application/firebase_auth_error_mapper.dart';
import 'package:jaga/features/auth/data/models/trusted_contact.dart';
import 'package:jaga/features/auth/data/models/user_profile.dart';

void main() {
  group('validasi nama panggilan', () {
    test('menerima nama yang sudah dipangkas dalam batas panjang', () {
      expect(validateDisplayName('  Nia  '), isNull);
    });

    test('menolak nama kurang dari 2 atau lebih dari 40 karakter', () {
      expect(validateDisplayName('A'), isNotNull);
      expect(validateDisplayName('A' * 41), isNotNull);
    });
  });

  group('validasi email', () {
    test('menormalkan email menjadi huruf kecil', () {
      expect(normalizeEmail('  NIA@Example.COM '), 'nia@example.com');
    });

    test('menerima email dasar yang valid dan menolak format salah', () {
      expect(validateEmail('nia@example.com'), isNull);
      expect(validateEmail('nia@'), isNotNull);
    });
  });

  group('validasi kata sandi', () {
    test('mewajibkan minimal delapan karakter', () {
      expect(validatePassword('1234567'), isNotNull);
      expect(validatePassword('12345678'), isNull);
    });

    test('konfirmasi harus sama dengan kata sandi', () {
      expect(
        validatePasswordConfirmation(
          password: 'rahasia8',
          confirmation: 'rahasia8',
        ),
        isNull,
      );
      expect(
        validatePasswordConfirmation(
          password: 'rahasia8',
          confirmation: 'berbeda8',
        ),
        isNotNull,
      );
    });
  });

  group('nomor ponsel Indonesia', () {
    test('menormalkan format 08, 62, dan +62 ke E.164', () {
      expect(normalizeIndonesianPhone('081234567890'), '+6281234567890');
      expect(normalizeIndonesianPhone('6281234567890'), '+6281234567890');
      expect(normalizeIndonesianPhone('+6281234567890'), '+6281234567890');
    });

    test('menerima pemisah umum dan menolak nomor yang tidak valid', () {
      expect(normalizeIndonesianPhone('0812-3456-7890'), '+6281234567890');
      expect(normalizeIndonesianPhone('021123456'), isNull);
      expect(normalizeIndonesianPhone('81234567890'), isNull);
    });
  });

  group('pemetaan error Firebase Authentication', () {
    test('menyamakan error kredensial tanpa mengungkap akun', () {
      const expected = 'Email atau kata sandi tidak sesuai.';
      expect(mapFirebaseAuthError('user-not-found'), expected);
      expect(mapFirebaseAuthError('wrong-password'), expected);
      expect(mapFirebaseAuthError('invalid-credential'), expected);
    });

    test('memetakan error yang diketahui dan error tidak dikenal', () {
      expect(
        mapFirebaseAuthError('invalid-email'),
        'Format email tidak valid.',
      );
      expect(
        mapFirebaseAuthError('network-request-failed'),
        contains('Koneksi internet'),
      );
      expect(
        mapFirebaseAuthError('something-new'),
        contains('Terjadi kendala'),
      );
    });
  });

  group('serialisasi profil pengguna', () {
    test('menyimpan dan membaca tepat delapan field profil', () {
      const profile = UserProfile(
        uid: 'uid-1',
        displayName: 'Nia',
        email: 'nia@example.com',
        phoneNumber: '+6281234567890',
        photoUrl: null,
        helperModeEnabled: false,
        communityAssistanceEnabled: false,
      );

      final map = profile.toMap(createdAt: 'created', updatedAt: 'updated');
      expect(map.keys, hasLength(8));
      expect(map['helperModeEnabled'], isFalse);
      expect(map['communityAssistanceEnabled'], isFalse);

      final restored = UserProfile.fromMap(uid: 'uid-1', map: map);
      expect(restored.displayName, profile.displayName);
      expect(restored.phoneNumber, profile.phoneNumber);
      expect(restored.createdAt, 'created');
    });
  });

  group('serialisasi kontak tepercaya', () {
    test('menyimpan dan membaca tepat enam field kontak', () {
      const contact = TrustedContact(
        displayName: 'Ibu',
        phoneNumber: '+6281234567890',
      );

      final map = contact.toMap(createdAt: 'created');
      expect(map.keys, hasLength(6));
      expect(map['contactUid'], isNull);
      expect(map['channel'], 'sms');
      expect(map['status'], 'accepted');

      final restored = TrustedContact.fromMap(map);
      expect(restored.displayName, contact.displayName);
      expect(restored.createdAt, 'created');
    });
  });
}

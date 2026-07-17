// ignore: depend_on_referenced_packages
import 'package:test/test.dart';
import 'package:jaga/features/profile/application/trusted_contact_policy.dart';
import 'package:jaga/features/profile/data/models/profile_settings.dart';
import 'package:jaga/features/profile/data/models/profile_trusted_contact.dart';

void main() {
  group('kebijakan kontak tepercaya', () {
    test('mencegah penghapusan kontak terakhir', () {
      expect(canDeleteTrustedContact(0), isFalse);
      expect(canDeleteTrustedContact(1), isFalse);
      expect(canDeleteTrustedContact(2), isTrue);
    });

    test('menyediakan pesan wajib yang ramah', () {
      expect(
        finalTrustedContactMessage,
        'Jaga memerlukan minimal satu kontak tepercaya. Tambahkan kontak lain sebelum menghapus kontak ini.',
      );
    });
  });

  group('pemetaan profil', () {
    test('membaca dan menulis delapan field tanpa mengubah schema', () {
      final profile = ProfileSettings.fromMap(
        uid: 'uid-1',
        map: <String, Object?>{
          'displayName': 'Nia',
          'email': 'nia@example.com',
          'phoneNumber': '+6281234567890',
          'photoUrl': null,
          'helperModeEnabled': true,
          'communityAssistanceEnabled': false,
          'createdAt': 'created',
          'updatedAt': 'updated',
        },
      );

      expect(profile.uid, 'uid-1');
      expect(profile.helperModeEnabled, isTrue);
      expect(profile.toMap().keys, hasLength(8));
      expect(profile.toMap()['phoneNumber'], '+6281234567890');
    });
  });

  group('pemetaan kontak tepercaya', () {
    test('mempertahankan seluruh field yang tidak boleh diubah saat edit', () {
      final contact = ProfileTrustedContact.fromMap(
        id: 'contact-1',
        map: <String, Object?>{
          'displayName': 'Ibu',
          'phoneNumber': '+6281234567890',
          'contactUid': null,
          'channel': 'sms',
          'status': 'accepted',
          'createdAt': 'created',
        },
      );

      expect(contact.id, 'contact-1');
      expect(contact.toMap().keys, hasLength(6));
      expect(contact.toMap()['channel'], 'sms');
      expect(contact.toMap()['status'], 'accepted');
      expect(contact.toMap()['createdAt'], 'created');
    });
  });
}

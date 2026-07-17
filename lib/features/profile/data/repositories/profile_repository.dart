import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/profile_settings.dart';
import '../models/profile_trusted_contact.dart';

class FinalTrustedContactException implements Exception {
  const FinalTrustedContactException();
}

class ProfileRepository {
  const ProfileRepository(this._firestore);

  final FirebaseFirestore _firestore;

  Stream<ProfileSettings?> watchProfile(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (!snapshot.exists || data == null) {
        return null;
      }
      return ProfileSettings.fromMap(uid: uid, map: data);
    });
  }

  Stream<List<ProfileTrustedContact>> watchTrustedContacts(String uid) {
    return _trustedContacts(uid).snapshots().map((snapshot) {
      return snapshot.docs
          .map(
            (document) => ProfileTrustedContact.fromMap(
              id: document.id,
              map: document.data(),
            ),
          )
          .toList(growable: false);
    });
  }

  Future<void> updateProfile({
    required String uid,
    String? displayName,
    String? phoneNumber,
  }) {
    final updates = <String, Object?>{};
    if (displayName != null) {
      updates['displayName'] = displayName;
    }
    if (phoneNumber != null) {
      updates['phoneNumber'] = phoneNumber;
    }
    if (updates.isEmpty) {
      return Future<void>.value();
    }
    updates['updatedAt'] = FieldValue.serverTimestamp();
    return _firestore.collection('users').doc(uid).update(updates);
  }

  Future<void> updateHelperMode({required String uid, required bool enabled}) {
    return _updatePreference(
      uid: uid,
      field: 'helperModeEnabled',
      enabled: enabled,
    );
  }

  Future<void> updateCommunityAssistance({
    required String uid,
    required bool enabled,
  }) {
    return _updatePreference(
      uid: uid,
      field: 'communityAssistanceEnabled',
      enabled: enabled,
    );
  }

  Future<void> createTrustedContact({
    required String uid,
    required String displayName,
    required String phoneNumber,
  }) {
    return _trustedContacts(uid).add(<String, Object?>{
      'displayName': displayName,
      'phoneNumber': phoneNumber,
      'contactUid': null,
      'channel': 'sms',
      'status': 'accepted',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateTrustedContact({
    required String uid,
    required String contactId,
    required String displayName,
    required String phoneNumber,
  }) {
    return _trustedContacts(uid).doc(contactId).update(<String, Object?>{
      'displayName': displayName,
      'phoneNumber': phoneNumber,
    });
  }

  Future<void> deleteTrustedContact({
    required String uid,
    required String contactId,
  }) async {
    final contacts = await _trustedContacts(uid).limit(2).get();
    if (contacts.docs.length <= 1) {
      throw const FinalTrustedContactException();
    }
    await _trustedContacts(uid).doc(contactId).delete();
  }

  Future<void> _updatePreference({
    required String uid,
    required String field,
    required bool enabled,
  }) {
    return _firestore.collection('users').doc(uid).update(<String, Object?>{
      field: enabled,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  CollectionReference<Map<String, dynamic>> _trustedContacts(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('trustedContacts');
  }
}

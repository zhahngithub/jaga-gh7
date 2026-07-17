import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart';

import '../models/distress_session.dart';

class DistressStartResult {
  const DistressStartResult({
    required this.sessionId,
    required this.recipientCount,
    required this.recipientDisplayNames,
  });

  final String sessionId;
  final int recipientCount;
  final List<String> recipientDisplayNames;
}

class TrustedContactRecipients {
  const TrustedContactRecipients({
    required this.phoneNumbers,
    required this.displayNames,
  });

  final List<String> phoneNumbers;
  final List<String> displayNames;

  bool get isEmpty => phoneNumbers.isEmpty;
}

class DistressRepository {
  DistressRepository.firebase()
    : _firestore = FirebaseFirestore.instance,
      _auth = FirebaseAuth.instance;

  const DistressRepository(this._firestore, this._auth);

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<DistressStartResult> startSession(LatLng location) async {
    final user = _requireUser();
    return _createSession(
      user: user,
      location: location,
      audience: 'nearby_helper',
      recipientUids: const <String>[],
      recipientDisplayNames: const <String>[],
    );
  }

  Future<TrustedContactRecipients> loadTrustedContactRecipients() async {
    final user = _requireUser();

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('trustedContacts')
          .get();
      final senderSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();
      final senderPhone = (senderSnapshot.data()?['phoneNumber'] as String?)
          ?.trim();
      final recipientsByPhone = <String, String>{};
      for (final document in snapshot.docs) {
        final data = document.data();
        if (data['status'] != 'accepted') continue;

        final phoneNumber = (data['phoneNumber'] as String?)?.trim();
        if (phoneNumber == null ||
            phoneNumber.isEmpty ||
            phoneNumber == senderPhone) {
          continue;
        }
        final displayName = (data['displayName'] as String?)?.trim();
        recipientsByPhone.putIfAbsent(
          phoneNumber,
          () => displayName == null || displayName.isEmpty
              ? 'Kontak darurat'
              : displayName,
        );
      }
      return TrustedContactRecipients(
        phoneNumbers: List<String>.unmodifiable(recipientsByPhone.keys),
        displayNames: List<String>.unmodifiable(recipientsByPhone.values),
      );
    } on FirebaseException catch (error) {
      throw DistressDataException(_messageForFirestoreError(error));
    }
  }

  Future<String?> findActiveOwnedSessionId() async {
    final user = _requireUser();
    try {
      final snapshot = await _firestore
          .collection('distressSessions')
          .where('senderUid', isEqualTo: user.uid)
          .get();
      for (final document in snapshot.docs) {
        final data = document.data();
        if (data['status'] != 'active') continue;
        final expiresAt = data['expiresAt'];
        if (expiresAt is Timestamp &&
            !expiresAt.toDate().isAfter(DateTime.now())) {
          continue;
        }
        return document.id;
      }
      return null;
    } on FirebaseException catch (error) {
      throw DistressDataException(_messageForFirestoreError(error));
    }
  }

  Future<DistressStartResult> startTrustedContactSession({
    required LatLng location,
    required List<String> recipientPhoneNumbers,
    required List<String> recipientDisplayNames,
  }) {
    final user = _requireUser();
    final uniqueRecipients = recipientPhoneNumbers
        .map((phoneNumber) => phoneNumber.trim())
        .where((phoneNumber) => phoneNumber.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (uniqueRecipients.isEmpty) {
      throw const DistressDataException(
        'Tidak ada nomor telepon kontak darurat yang valid.',
      );
    }
    return _createSession(
      user: user,
      location: location,
      audience: 'trusted_contact',
      recipientUids: const <String>[],
      recipientPhoneNumbers: uniqueRecipients,
      recipientDisplayNames: recipientDisplayNames,
    );
  }

  Future<void> updateLocation(String sessionId, LatLng location) async {
    try {
      await _firestore
          .collection('distressSessions')
          .doc(sessionId)
          .update(<String, Object>{
            'preciseLocation': GeoPoint(location.latitude, location.longitude),
            'updatedAt': FieldValue.serverTimestamp(),
          });
    } on FirebaseException catch (error) {
      throw DistressDataException(_messageForFirestoreError(error));
    }
  }

  Future<void> escalateToNearbyHelpers(String sessionId) async {
    try {
      await _firestore.collection('distressSessions').doc(sessionId).update(
        <String, Object>{
          'audience': 'nearby_helper',
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
    } on FirebaseException catch (error) {
      throw DistressDataException(_messageForFirestoreError(error));
    }
  }

  Future<void> stopSession(String sessionId) async {
    try {
      await _firestore.collection('distressSessions').doc(sessionId).update(
        <String, Object>{
          'status': 'ended',
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
    } on FirebaseException catch (error) {
      throw DistressDataException(_messageForFirestoreError(error));
    }
  }

  Stream<DistressSession> watchSession(String sessionId) {
    return _firestore
        .collection('distressSessions')
        .doc(sessionId)
        .snapshots()
        .map(DistressSession.fromFirestore)
        .handleError((Object error) {
          if (error is FirebaseException && error.code == 'permission-denied') {
            throw const DistressDataException(
              'Kamu tidak memiliki akses ke sesi darurat ini.',
            );
          }
          throw error;
        });
  }

  User _requireUser() {
    final user = _auth.currentUser;
    if (user == null) {
      throw const DistressDataException('Masuk ke akun Jaga terlebih dahulu.');
    }
    return user;
  }

  Future<DistressStartResult> _createSession({
    required User user,
    required LatLng location,
    required String audience,
    required List<String> recipientUids,
    List<String> recipientPhoneNumbers = const <String>[],
    required List<String> recipientDisplayNames,
  }) async {
    try {
      final senderSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();
      final senderDisplayName =
          senderSnapshot.data()?['displayName'] as String? ?? 'Pengguna Jaga';
      final sessionReference = _firestore.collection('distressSessions').doc();
      await sessionReference.set(<String, Object>{
        'senderUid': user.uid,
        'recipientUids': recipientUids,
        'recipientPhoneNumbers': recipientPhoneNumbers,
        'senderDisplayName': senderDisplayName,
        'audience': audience,
        'status': 'active',
        'preciseLocation': GeoPoint(location.latitude, location.longitude),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(hours: 1)),
        ),
      });
      return DistressStartResult(
        sessionId: sessionReference.id,
        recipientCount: audience == 'trusted_contact'
            ? recipientPhoneNumbers.length
            : recipientUids.length,
        recipientDisplayNames: recipientDisplayNames,
      );
    } on FirebaseException catch (error) {
      throw DistressDataException(_messageForFirestoreError(error));
    }
  }

  String _messageForFirestoreError(FirebaseException error) {
    return switch (error.code) {
      'permission-denied' => 'Kamu tidak diizinkan mengubah sesi darurat ini.',
      'not-found' => 'Sesi darurat tidak ditemukan.',
      'unavailable' => 'Koneksi ke layanan darurat sedang tidak tersedia.',
      _ => 'Sesi darurat belum dapat diproses. Coba lagi.',
    };
  }
}

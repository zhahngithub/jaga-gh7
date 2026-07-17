import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

enum DistressStatus { active, ended, expired }

class DistressSession {
  const DistressSession({
    required this.id,
    required this.senderUid,
    required this.recipientUids,
    required this.senderDisplayName,
    required this.audience,
    required this.status,
    required this.preciseLocation,
    required this.updatedAt,
    required this.expiresAt,
  });

  final String id;
  final String senderUid;
  final List<String> recipientUids;
  final String senderDisplayName;
  final String audience;
  final DistressStatus status;
  final LatLng preciseLocation;
  final DateTime? updatedAt;
  final DateTime? expiresAt;

  bool get isActive => status == DistressStatus.active && !hasExpired;

  bool get hasExpired {
    final expiry = expiresAt;
    return expiry != null && expiry.isBefore(DateTime.now());
  }

  DistressStatus get effectiveStatus {
    if (status == DistressStatus.active && hasExpired) {
      return DistressStatus.expired;
    }
    return status;
  }

  factory DistressSession.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    if (!snapshot.exists || data == null) {
      throw const DistressDataException('Sesi darurat tidak ditemukan.');
    }
    final location = data['preciseLocation'];
    if (location is! GeoPoint) {
      throw const DistressDataException('Lokasi sesi darurat tidak tersedia.');
    }
    return DistressSession(
      id: snapshot.id,
      senderUid: data['senderUid'] as String? ?? '',
      recipientUids: (data['recipientUids'] as List<Object?>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      senderDisplayName:
          data['senderDisplayName'] as String? ?? 'Pengguna Jaga',
      audience: data['audience'] as String? ?? 'trusted_contact',
      status: _parseStatus(data['status']),
      preciseLocation: LatLng(location.latitude, location.longitude),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
    );
  }

  static DistressStatus _parseStatus(Object? value) {
    return switch (value) {
      'ended' => DistressStatus.ended,
      'expired' => DistressStatus.expired,
      _ => DistressStatus.active,
    };
  }
}

class DistressDataException implements Exception {
  const DistressDataException(this.message);

  final String message;

  @override
  String toString() => message;
}

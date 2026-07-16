class TrustedContact {
  const TrustedContact({
    required this.displayName,
    required this.phoneNumber,
    this.contactUid,
    this.channel = 'sms',
    this.status = 'accepted',
    this.createdAt,
  });

  final String displayName;
  final String phoneNumber;
  final String? contactUid;
  final String channel;
  final String status;
  final Object? createdAt;

  factory TrustedContact.fromMap(Map<String, Object?> map) {
    return TrustedContact(
      displayName: map['displayName']! as String,
      phoneNumber: map['phoneNumber']! as String,
      contactUid: map['contactUid'] as String?,
      channel: map['channel']! as String,
      status: map['status']! as String,
      createdAt: map['createdAt'],
    );
  }

  Map<String, Object?> toMap({required Object createdAt}) {
    return <String, Object?>{
      'displayName': displayName,
      'phoneNumber': phoneNumber,
      'contactUid': contactUid,
      'channel': channel,
      'status': status,
      'createdAt': createdAt,
    };
  }
}

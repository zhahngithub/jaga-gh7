class ProfileTrustedContact {
  const ProfileTrustedContact({
    required this.id,
    required this.displayName,
    required this.phoneNumber,
    required this.contactUid,
    required this.channel,
    required this.status,
    this.createdAt,
  });

  final String id;
  final String displayName;
  final String phoneNumber;
  final String? contactUid;
  final String channel;
  final String status;
  final Object? createdAt;

  factory ProfileTrustedContact.fromMap({
    required String id,
    required Map<String, Object?> map,
  }) {
    return ProfileTrustedContact(
      id: id,
      displayName: map['displayName']! as String,
      phoneNumber: map['phoneNumber']! as String,
      contactUid: map['contactUid'] as String?,
      channel: map['channel']! as String,
      status: map['status']! as String,
      createdAt: map['createdAt'],
    );
  }

  Map<String, Object?> toMap() {
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

class ProfileSettings {
  const ProfileSettings({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.phoneNumber,
    required this.photoUrl,
    required this.helperModeEnabled,
    required this.communityAssistanceEnabled,
    this.createdAt,
    this.updatedAt,
  });

  final String uid;
  final String displayName;
  final String email;
  final String phoneNumber;
  final String? photoUrl;
  final bool helperModeEnabled;
  final bool communityAssistanceEnabled;
  final Object? createdAt;
  final Object? updatedAt;

  factory ProfileSettings.fromMap({
    required String uid,
    required Map<String, Object?> map,
  }) {
    return ProfileSettings(
      uid: uid,
      displayName: map['displayName']! as String,
      email: map['email']! as String,
      phoneNumber: map['phoneNumber']! as String,
      photoUrl: map['photoUrl'] as String?,
      helperModeEnabled: map['helperModeEnabled']! as bool,
      communityAssistanceEnabled: map['communityAssistanceEnabled']! as bool,
      createdAt: map['createdAt'],
      updatedAt: map['updatedAt'],
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'displayName': displayName,
      'email': email,
      'phoneNumber': phoneNumber,
      'photoUrl': photoUrl,
      'helperModeEnabled': helperModeEnabled,
      'communityAssistanceEnabled': communityAssistanceEnabled,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}

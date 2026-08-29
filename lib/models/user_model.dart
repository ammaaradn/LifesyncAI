import 'package:cloud_firestore/cloud_firestore.dart';

/// Basic profile info stored in Firestore at `users/{uid}` when an account
/// is created. Kept separate from [firebase_auth]'s `User` object, which
/// only carries auth-level fields (email, uid, etc).
class UserModel {
  final String uid;
  final String name;
  final String email;
  final DateTime createdAt;
  final bool notificationsEnabled;

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.createdAt,
    this.notificationsEnabled = true,
  });

  /// Builds a [UserModel] from a Firestore document snapshot's data map.
  factory UserModel.fromMap(String uid, Map<String, dynamic> map) {
    return UserModel(
      uid: uid,
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      notificationsEnabled: map['notificationsEnabled'] as bool? ?? true,
    );
  }

  /// Converts this model into a map suitable for writing to Firestore.
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'createdAt': Timestamp.fromDate(createdAt),
      'notificationsEnabled': notificationsEnabled,
    };
  }
}

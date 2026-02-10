import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String phoneNumber;
  final String? email;
  final String name;
  final String role; // 'patient', 'assistant', 'doctor'
  final bool isShadowAccount; // True if created by assistant for walk-in
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.phoneNumber,
    this.email,
    required this.name,
    required this.role,
    this.isShadowAccount = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'phoneNumber': phoneNumber,
      'email': email,
      'name': name,
      'role': role,
      'isShadowAccount': isShadowAccount,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      email: map['email'],
      name: map['name'] ?? 'Unknown',
      role: map['role'] ?? 'patient',
      isShadowAccount: map['isShadowAccount'] ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
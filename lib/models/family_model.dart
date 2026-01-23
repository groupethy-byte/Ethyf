import 'package:cloud_firestore/cloud_firestore.dart';

class FamilyModel {
  final String id;
  final String ownerUid;
  final List<String> memberUids;
  final String familyName;
  final bool isPro;
  final DateTime createdAt;
  final DateTime updatedAt;

  FamilyModel({
    required this.id,
    required this.ownerUid,
    required this.memberUids,
    required this.familyName,
    this.isPro = false,
    required this.createdAt,
    required this.updatedAt,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'ownerUid': ownerUid,
      'memberUids': memberUids,
      'familyName': familyName,
      'isPro': isPro,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  // Convert from Map
  factory FamilyModel.fromMap(String id, Map<String, dynamic> map) {
    return FamilyModel(
      id: id,
      ownerUid: map['ownerUid'] ?? '',
      memberUids: List<String>.from(map['memberUids'] ?? []),
      familyName: map['familyName'] ?? 'My Family',
      isPro: map['isPro'] ?? false,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }
}
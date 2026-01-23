import 'package:cloud_firestore/cloud_firestore.dart';

class TransaksiModel {
  final String id;
  final String userId;
  final String? familyId; // Make familyId nullable
  final DateTime tanggal;
  final String bankId;
  final String kategoriId;
  final String subKategoriId;
  final String catatan;
  final int nilai;
  final String? fotoStrukUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  TransaksiModel({
    required this.id,
    required this.userId,
    this.familyId, // Make familyId optional
    required this.tanggal,
    required this.bankId,
    required this.kategoriId,
    required this.subKategoriId,
    required this.catatan,
    required this.nilai,
    this.fotoStrukUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  // Convert to Map untuk Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      if (familyId != null) 'familyId': familyId, // Include familyId only if not null
      'tanggal': tanggal,
      'bankId': bankId,
      'kategoriId': kategoriId,
      'subKategoriId': subKategoriId,
      'catatan': catatan,
      'nilai': nilai,
      'fotoStrukUrl': fotoStrukUrl,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  // Convert from Map
  factory TransaksiModel.fromMap(String id, Map<String, dynamic> map) {
    return TransaksiModel(
      id: id,
      userId: map['userId'] ?? '',
      familyId: map['familyId'] as String?, // Directly assign, can be null
      tanggal: (map['tanggal'] as dynamic)?.toDate() ?? DateTime.now(),
      bankId: map['bankId'] ?? '',
      kategoriId: map['kategoriId'] ?? '',
      subKategoriId: map['subKategoriId'] ?? '',
      catatan: map['catatan'] ?? '',
      nilai: map['nilai'] ?? 0,
      fotoStrukUrl: map['fotoStrukUrl'],
      createdAt: (map['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }
}
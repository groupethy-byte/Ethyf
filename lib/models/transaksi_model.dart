class TransaksiModel {
  final String id;
  final String userId;
  final DateTime tanggal;
  final String bankId;
  final String kategoriId;
  final String subKategoriId;
  final String catatan;
  final int nilai;
  final String? fotoStukUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  TransaksiModel({
    required this.id,
    required this.userId,
    required this.tanggal,
    required this.bankId,
    required this.kategoriId,
    required this.subKategoriId,
    required this.catatan,
    required this.nilai,
    this.fotoStukUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  // Convert to Map untuk Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'tanggal': tanggal,
      'bankId': bankId,
      'kategoriId': kategoriId,
      'subKategoriId': subKategoriId,
      'catatan': catatan,
      'nilai': nilai,
      'fotoStukUrl': fotoStukUrl,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  // Convert from Map
  factory TransaksiModel.fromMap(String id, Map<String, dynamic> map) {
    return TransaksiModel(
      id: id,
      userId: map['userId'] ?? '',
      tanggal: (map['tanggal'] as dynamic)?.toDate() ?? DateTime.now(),
      bankId: map['bankId'] ?? '',
      kategoriId: map['kategoriId'] ?? '',
      subKategoriId: map['subKategoriId'] ?? '',
      catatan: map['catatan'] ?? '',
      nilai: map['nilai'] ?? 0,
      fotoStukUrl: map['fotoStukUrl'],
      createdAt: (map['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }
}

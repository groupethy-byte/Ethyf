import 'package:hive_flutter/hive_flutter.dart';

class LocalDatabaseService {
  static const String _banksBox = 'banks';
  static const String _kategoriBox = 'kategori';
  static const String _subKategoriBox = 'subkategori';
  static const String _transaksiBox = 'transaksi';

  static Future<void> initHive() async {
    await Hive.initFlutter();
    await Hive.openBox(_banksBox);
    await Hive.openBox(_kategoriBox);
    await Hive.openBox(_subKategoriBox);
    await Hive.openBox(_transaksiBox);
  }

  // Helper function untuk convert Timestamp ke DateTime
  static Map<String, dynamic> _convertTimestamps(Map<String, dynamic> data) {
    final converted = {...data};
    converted.forEach((key, value) {
      if (value is Map && value.containsKey('_seconds')) {
        // Convert Firestore Timestamp
        final seconds = value['_seconds'] as int;
        final nanoseconds = value['_nanoseconds'] as int? ?? 0;
        converted[key] = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      } else if (value.runtimeType.toString().contains('Timestamp')) {
        // Alternative: handle Timestamp.toDate()
        converted[key] = value.toDate();
      }
    });
    return converted;
  }

  // Bank operations
  static Future<void> saveBanks(List<Map<String, dynamic>> banks) async {
    final box = Hive.box(_banksBox);
    await box.clear();
    for (var bank in banks) {
      final converted = _convertTimestamps(bank);
      await box.put(bank['id'], converted);
    }
  }

  static List<Map<String, dynamic>> getBanks() {
    final box = Hive.box(_banksBox);
    return box.values.cast<Map<String, dynamic>>().toList();
  }

  static Future<void> saveBank(String id, Map<String, dynamic> bank) async {
    final box = Hive.box(_banksBox);
    final converted = _convertTimestamps(bank);
    await box.put(id, converted);
  }

  static Future<void> deleteBank(String id) async {
    final box = Hive.box(_banksBox);
    await box.delete(id);
  }

  // Kategori operations
  static Future<void> saveKategori(List<Map<String, dynamic>> kategori) async {
    final box = Hive.box(_kategoriBox);
    await box.clear();
    for (var kat in kategori) {
      final converted = _convertTimestamps(kat);
      await box.put(kat['id'], converted);
    }
  }

  static List<Map<String, dynamic>> getKategori() {
    final box = Hive.box(_kategoriBox);
    return box.values.cast<Map<String, dynamic>>().toList();
  }

  static Future<void> saveKat(String id, Map<String, dynamic> kat) async {
    final box = Hive.box(_kategoriBox);
    final converted = _convertTimestamps(kat);
    await box.put(id, converted);
  }

  static Future<void> deleteKat(String id) async {
    final box = Hive.box(_kategoriBox);
    await box.delete(id);
  }

  // Sub Kategori operations
  static Future<void> saveSubKategori(List<Map<String, dynamic>> subKat) async {
    final box = Hive.box(_subKategoriBox);
    await box.clear();
    for (var sk in subKat) {
      final converted = _convertTimestamps(sk);
      await box.put(sk['id'], converted);
    }
  }

  static List<Map<String, dynamic>> getSubKategori() {
    final box = Hive.box(_subKategoriBox);
    return box.values.cast<Map<String, dynamic>>().toList();
  }

  static Future<void> saveSubKat(String id, Map<String, dynamic> subKat) async {
    final box = Hive.box(_subKategoriBox);
    final converted = _convertTimestamps(subKat);
    await box.put(id, converted);
  }

  static Future<void> deleteSubKat(String id) async {
    final box = Hive.box(_subKategoriBox);
    await box.delete(id);
  }

  // Transaksi operations
  static Future<void> saveTransaksi(List<Map<String, dynamic>> transaksi) async {
    final box = Hive.box(_transaksiBox);
    await box.clear();
    for (var t in transaksi) {
      final converted = _convertTimestamps(t);
      await box.put(t['id'], converted);
    }
  }

  static List<Map<String, dynamic>> getTransaksi() {
    final box = Hive.box(_transaksiBox);
    return box.values.cast<Map<String, dynamic>>().toList();
  }

  static Future<void> saveTransaksiItem(String id, Map<String, dynamic> transaksi) async {
    final box = Hive.box(_transaksiBox);
    final converted = _convertTimestamps(transaksi);
    await box.put(id, converted);
  }

  static Future<void> deleteTransaksi(String id) async {
    final box = Hive.box(_transaksiBox);
    await box.delete(id);
  }
}

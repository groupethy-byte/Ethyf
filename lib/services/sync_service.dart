import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'local_database_service.dart';

class SyncService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final Connectivity _connectivity = Connectivity();

  static Future<bool> isOnline() async {
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }

  static Future<void> syncAllData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final online = await isOnline();
      if (!online) return;

      await _syncBanks(user.uid);
      await _syncKategori(user.uid);
      await _syncSubKategori(user.uid);

      print('Sync completed successfully');
    } catch (e) {
      print('Sync error: $e');
    }
  }

  static Future<void> _syncBanks(String uid) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('banks')
          .get();

      final banks = snapshot.docs
          .map((doc) {
            final data = doc.data();
            // Convert Timestamps ke DateTime
            if (data['createdAt'] != null) {
              data['createdAt'] = (data['createdAt'] as dynamic).toDate();
            }
            if (data['updatedAt'] != null) {
              data['updatedAt'] = (data['updatedAt'] as dynamic).toDate();
            }
            return {
              'id': doc.id,
              ...data,
            };
          })
          .toList();

      await LocalDatabaseService.saveBanks(banks);
    } catch (e) {
      print('Sync banks error: $e');
    }
  }

  static Future<void> _syncKategori(String uid) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('kategori')
          .get();

      final kategori = snapshot.docs
          .map((doc) {
            final data = doc.data();
            // Convert Timestamps ke DateTime
            if (data['createdAt'] != null) {
              data['createdAt'] = (data['createdAt'] as dynamic).toDate();
            }
            if (data['updatedAt'] != null) {
              data['updatedAt'] = (data['updatedAt'] as dynamic).toDate();
            }
            return {
              'id': doc.id,
              ...data,
            };
          })
          .toList();

      await LocalDatabaseService.saveKategori(kategori);
    } catch (e) {
      print('Sync kategori error: $e');
    }
  }

  static Future<void> _syncSubKategori(String uid) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('subkategori')
          .get();

      final subKat = snapshot.docs
          .map((doc) {
            final data = doc.data();
            // Convert Timestamps ke DateTime
            if (data['createdAt'] != null) {
              data['createdAt'] = (data['createdAt'] as dynamic).toDate();
            }
            if (data['updatedAt'] != null) {
              data['updatedAt'] = (data['updatedAt'] as dynamic).toDate();
            }
            return {
              'id': doc.id,
              ...data,
            };
          })
          .toList();

      await LocalDatabaseService.saveSubKategori(subKat);
    } catch (e) {
      print('Sync sub kategori error: $e');
    }
  }
}

void main() {
  // Ensure that all dependencies are fetched and the app is run in Chrome
  // This is typically done in the terminal, not in the Dart code
  // flutter pub get
  // flutter run -d chrome
}

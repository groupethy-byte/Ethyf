import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ethyf/models/family_model.dart';
import 'package:ethyf/utils/user_utils.dart';

class FamilyController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? get user => FirebaseAuth.instance.currentUser;

  Rx<FamilyModel?> currentFamily = Rx<FamilyModel?>(null);
  RxList<Map<String, String>> familyMembers = RxList<Map<String, String>>([]);
  RxList<QueryDocumentSnapshot> pendingInvitations = RxList<QueryDocumentSnapshot>([]);
  RxList<QueryDocumentSnapshot> sentInvitations = RxList<QueryDocumentSnapshot>([]);
  RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    _fetchFamilyData();
    _listenToInvitations();
  }

  void _listenToInvitations() {
    if (user == null) return;
    print("DEBUG: Memulai listener undangan untuk UID: ${user!.uid}");
    _firestore
        .collection('invitations')
        .where('inviteeUid', isEqualTo: user!.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      pendingInvitations.value = snapshot.docs;
      print("DEBUG: Undangan ditemukan: ${snapshot.docs.length}");
    }, onError: (e) {
      print("Error listening to invitations: $e");
    });
  }

  void _listenToSentInvitations(String familyId) {
    _firestore
        .collection('invitations')
        .where('familyId', isEqualTo: familyId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      sentInvitations.value = snapshot.docs;
    }, onError: (e) {
      print("Error listening to sent invitations: $e");
    });
  }

  Future<void> _fetchFamilyData() async {
    if (user == null) return;

    isLoading.value = true;
    try {
      final familyId = await UserUtils.getCurrentUserFamilyId();
      if (familyId != null) {
        final familyDoc = await _firestore.collection('families').doc(familyId).get();
        if (familyDoc.exists) {
          final familyData = familyDoc.data()!;
          currentFamily.value = FamilyModel.fromMap(familyDoc.id, familyData);
          
          // Hanya owner yang bisa melihat undangan keluar (menghindari Permission Denied untuk member biasa)
          if (currentFamily.value?.ownerUid == user?.uid) {
            _listenToSentInvitations(familyDoc.id);
          }
          // familyMembers.value = await UserUtils.getFamilyMembers(familyId); // Diganti dengan implementasi manual

          // Ambil nama anggota keluarga secara manual untuk memastikan data nama benar
          final List<String> memberUids = List<String>.from(familyData['memberUids'] ?? []);
          final List<Map<String, String>> members = [];
          for (String uid in memberUids) {
            final userDoc = await _firestore.collection('users').doc(uid).get();
            if (userDoc.exists) {
              members.add({'uid': uid, 'name': userDoc.data()?['fullName'] ?? 'Nama tidak ditemukan'});
            }
          }
          familyMembers.value = members;
        } else {
          // Self-healing: Jika familyId ada di user tapi dokumen family tidak ditemukan (sudah dihapus)
          print("Family doc not found. Cleaning up user profile.");
          await _firestore.collection('users').doc(user!.uid).update({
            'familyId': FieldValue.delete(),
            'isProMember': false,
          });
          currentFamily.value = null;
        }
      }
    } catch (e) {
      print("Error fetching family data: $e");
      // Handle error
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> inviteMember(String emailOrUid) async {
    // Bersihkan input dari spasi di awal/akhir
    final String cleanInput = emailOrUid.trim();

    // TODO: Implement actual invitation logic (e.g., generate invite code, send email)
    print("Inviting $cleanInput to family ${currentFamily.value?.familyName}");
    // For now, just add a dummy member if family exists
    if (currentFamily.value != null && user != null) {
      DocumentReference<Map<String, dynamic>>? invitationRef; // Deklarasikan di sini agar bisa diakses di catch
      try {
        // Validasi: Hanya owner yang bisa mengundang
        if (user!.uid != currentFamily.value!.ownerUid) {
          Get.snackbar("Akses Ditolak", "Hanya admin keluarga yang dapat mengundang anggota.");
          return;
        }

        String invitedUid = cleanInput;
        String inviteeName = 'User';

        // Cek apakah input adalah email
        if (cleanInput.contains('@')) {
          final userQuery = await _firestore.collection('users').where('email', isEqualTo: cleanInput.toLowerCase()).limit(1).get();
          if (userQuery.docs.isNotEmpty) {
            invitedUid = userQuery.docs.first.id;
            inviteeName = userQuery.docs.first.data()['fullName'] ?? 'User';
          } else {
            Get.snackbar("Error", "User dengan email '$cleanInput' tidak ditemukan.");
            return;
          }
        } else {
          // Jika bukan email, asumsikan input adalah UID
          final invitedUserDoc = await _firestore.collection('users').doc(invitedUid).get();
          if (!invitedUserDoc.exists) {
            Get.snackbar("Error", "User dengan UID tersebut tidak ditemukan.");
            return;
          }
          inviteeName = invitedUserDoc.data()?['fullName'] ?? 'User';
        }

        if (invitedUid == user!.uid) {
          Get.snackbar("Info", "Anda tidak dapat mengundang diri sendiri.");
          return;
        }

        // Cek apakah user sudah menjadi anggota
        if (currentFamily.value!.memberUids.contains(invitedUid)) {
          Get.snackbar("Info", "User ini sudah menjadi anggota keluarga.");
          return;
        }

        // Buat ID undangan yang dapat diprediksi
        final invitationId = '${currentFamily.value!.id}_$invitedUid';
        invitationRef = _firestore.collection('invitations').doc(invitationId);

        // Cek apakah undangan sudah pernah dikirim dan masih pending
        final existingInviteDoc = await invitationRef.get();

        if (existingInviteDoc.exists && existingInviteDoc.data()?['status'] == 'pending') {
          Get.snackbar("Info", "Undangan sudah dikirim dan menunggu konfirmasi.");
          return;
        }

        print("DEBUG: Mengirim undangan ke UID: $invitedUid (Nama: $inviteeName)");

        // Buat Undangan Baru
        await invitationRef.set({
          'familyId': currentFamily.value!.id,
          'familyName': currentFamily.value!.familyName,
          'inviterUid': user!.uid,
          'inviterName': user!.displayName ?? 'Admin',
          'inviteeUid': invitedUid,
          'inviteeName': inviteeName, // Simpan nama penerima agar bisa ditampilkan
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });

        Get.snackbar("Sukses", "Undangan dikirim ke $cleanInput. Menunggu konfirmasi.");
      } catch (e) {
        // Log yang lebih detail untuk debugging
        print("--- INVITE MEMBER FAILED ---");
        print("Error: $e");
        print("Current User UID: ${user?.uid}");
        print("Current Family ID: ${currentFamily.value?.id}");
        print("Current Family Owner UID: ${currentFamily.value?.ownerUid}");        
        print("Data yang dikirim: ${invitationRef?.path ?? 'N/A'}");
        print("----------------------------");
        Get.snackbar("Error", "Gagal mengundang anggota. Lihat log di console untuk detail.");
      }
    }
  }

  Future<void> acceptInvitation(String invitationId, String familyId) async {
    if (user == null) {
      Get.snackbar("Error", "User not logged in.");
      return;
    }
    isLoading.value = true;
    
    // Gunakan WriteBatch untuk operasi atomik (semua berhasil atau semua gagal)
    final batch = _firestore.batch();

    // DEBUG: Cek format ID Undangan
    final expectedInvitationId = '${familyId}_${user!.uid}';
    if (invitationId != expectedInvitationId) {
      print("WARNING: ID Undangan tidak sesuai format baru.");
      print("Received: $invitationId");
      print("Expected: $expectedInvitationId");
    }

    try {
      // 1. Siapkan update untuk dokumen keluarga (menambahkan user)
      final familyRef = _firestore.collection('families').doc(familyId);
      batch.update(familyRef, {
        'memberUids': FieldValue.arrayUnion([user!.uid]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 2. Siapkan update untuk dokumen user (menambahkan link ke keluarga)
      final userRef = _firestore.collection('users').doc(user!.uid);
      batch.update(userRef, {
        'familyId': familyId,
        'isProMember': true,
      });

      // 3. Update status undangan
      // Cari SEMUA undangan pending untuk user ini di keluarga ini dan update statusnya
      // Ini menangani kasus jika ada duplikat undangan atau ID yang tidak sinkron
      final pendingInvites = await _firestore
          .collection('invitations')
          .where('familyId', isEqualTo: familyId)
          .where('inviteeUid', isEqualTo: user!.uid)
          .where('status', isEqualTo: 'pending')
          .get();

      if (pendingInvites.docs.isNotEmpty) {
        for (var doc in pendingInvites.docs) {
          batch.update(doc.reference, {
            'status': 'accepted',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      } else {
        // Fallback jika query tidak menemukan hasil, gunakan ID spesifik
        final invitationRef = _firestore.collection('invitations').doc(invitationId);
        batch.update(invitationRef, {
          'status': 'accepted',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Jalankan semua operasi tulis sekaligus
      await batch.commit();

      Get.snackbar("Sukses", "Selamat! Anda berhasil bergabung dengan keluarga.");
      _fetchFamilyData(); // Refresh data
    } catch (e) {
      Get.snackbar("Error", "Gagal menerima undangan: $e");
      // Log yang lebih detail untuk debugging
      print("--- ACCEPT INVITATION FAILED ---");
      print("Error: $e");
      print("---------------------------------");
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> rejectInvitation(String invitationId) async {
    try {
      await _firestore.collection('invitations').doc(invitationId).update({
        'status': 'rejected',
      });
      Get.snackbar("Info", "Undangan ditolak.");
    } catch (e) {
      Get.snackbar("Error", "Gagal menolak undangan: $e");
    }
  }

  Future<void> cancelInvitation(String invitationId) async {
    try {
      await _firestore.collection('invitations').doc(invitationId).delete();
      Get.snackbar("Sukses", "Undangan dibatalkan.");
    } catch (e) {
      Get.snackbar("Error", "Gagal membatalkan undangan: $e");
    }
  }

  Future<void> upgradeFamilyToPro() async {
    if (user == null || currentFamily.value == null || currentFamily.value!.isPro) {
      Get.snackbar("Info", "Keluarga sudah Pro atau Anda tidak punya keluarga.");
      return;
    }
    if (user!.uid != currentFamily.value!.ownerUid) {
      Get.snackbar("Error", "Hanya pemilik keluarga yang dapat melakukan upgrade.");
      return;
    }

    isLoading.value = true;
    try {
      // 1. Update family document to isPro: true
      await _firestore.collection('families').doc(currentFamily.value!.id).update({
        'isPro': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 2. Update all family members' user documents to isProMember: true
      for (String memberUid in currentFamily.value!.memberUids) {
        await _firestore.collection('users').doc(memberUid).set({
          'isProMember': true,
        }, SetOptions(merge: true));
      }

      Get.snackbar("Success", "Keluarga berhasil di-upgrade ke status Pro!");
      _fetchFamilyData(); // Refresh data
    } catch (e) {
      print("Error upgrading family to Pro: $e");
      Get.snackbar("Error", "Gagal meng-upgrade keluarga ke Pro: $e");
    } finally {
      isLoading.value = false;
    }
  }
  
  Future<void> createFamily(String familyName) async {
    if (user == null) {
      Get.snackbar("Error", "User not logged in.");
      return;
    }

    isLoading.value = true;
    try {
      final newFamilyRef = await _firestore.collection('families').add({
        'ownerUid': user!.uid,
        'memberUids': [user!.uid],
        'familyName': familyName,
        'isPro': true, // Initially, family is Pro for testing
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update current user's document with familyId and isProMember status
      await _firestore.collection('users').doc(user!.uid).set({
        'familyId': newFamilyRef.id,
        'isProMember': true, // Sync with family's isPro status
      }, SetOptions(merge: true));

      Get.snackbar("Success", "Keluarga '$familyName' berhasil dibuat!");
      _fetchFamilyData(); // Refresh data
    } catch (e) {
      print("Error creating family: $e");
      Get.snackbar("Error", "Gagal membuat keluarga: $e");
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> removeMember(String memberUid) async {
    if (user == null || currentFamily.value == null) {
      Get.snackbar("Error", "Data keluarga tidak ditemukan.");
      return;
    }

    // Security check: Only owner can remove members
    if (user!.uid != currentFamily.value!.ownerUid) {
      Get.snackbar("Akses Ditolak", "Hanya admin yang bisa menghapus anggota.");
      return;
    }

    // Cannot remove self
    if (memberUid == user!.uid) {
      Get.snackbar("Info", "Admin tidak dapat menghapus diri sendiri.");
      return;
    }

    // Show confirmation dialog
    Get.defaultDialog(
      title: "Hapus Anggota",
      middleText: "Apakah Anda yakin ingin menghapus anggota ini dari keluarga? Tindakan ini tidak dapat dibatalkan.",
      textConfirm: "Hapus",
      textCancel: "Batal",
      confirmTextColor: Colors.white,
      onConfirm: () async {
        Get.back(); // Close dialog
        isLoading.value = true;
        try {
          // 1. Remove member from family's memberUids array
          await _firestore.collection('families').doc(currentFamily.value!.id).update({
            'memberUids': FieldValue.arrayRemove([memberUid]),
            'updatedAt': FieldValue.serverTimestamp(),
          });

          // 2. Update the removed user's document to remove family link
          await _firestore.collection('users').doc(memberUid).update({
            'familyId': FieldValue.delete(),
            'isProMember': FieldValue.delete(),
          });

          Get.snackbar("Sukses", "Anggota berhasil dihapus dari keluarga.");
          _fetchFamilyData(); // Refresh the list
        } catch (e) {
          Get.snackbar("Error", "Gagal menghapus anggota: $e");
        } finally {
          isLoading.value = false;
        }
      },
    );
  }

  Future<void> deleteFamily() async {
    if (user == null || currentFamily.value == null) {
      Get.snackbar("Error", "Data keluarga tidak ditemukan.");
      return;
    }

    // Security check: Only owner can delete the family
    if (user!.uid != currentFamily.value!.ownerUid) {
      Get.snackbar("Akses Ditolak", "Hanya admin yang bisa menghapus keluarga.");
      return;
    }

    isLoading.value = true;
    
    try {
      // Hapus dokumen keluarga secara langsung (Client Side)
      // Pastikan Security Rules di Firestore sudah mengizinkan delete untuk owner!
      await _firestore.collection('families').doc(currentFamily.value!.id).delete();

      // Update data user saat ini (Owner)
      await _firestore.collection('users').doc(user!.uid).update({
        'familyId': FieldValue.delete(),
        'isProMember': false, // Kembalikan ke status free
      });

      Get.snackbar("Sukses", "Keluarga berhasil dihapus.");
      
      // Clear local state
      currentFamily.value = null;
      familyMembers.clear();
      sentInvitations.clear();
      
    } catch (e) {
        Get.snackbar(
          "Error", 
          "Gagal menghapus keluarga: $e",
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 8)
        );
        print("Error deleting family: $e");
    } finally {
        isLoading.value = false;
    }
  }
}
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ethyf/models/family_model.dart';
import 'package:ethyf/utils/user_utils.dart';

class FamilyController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final user = FirebaseAuth.instance.currentUser;

  Rx<FamilyModel?> currentFamily = Rx<FamilyModel?>(null);
  RxList<Map<String, String>> familyMembers = RxList<Map<String, String>>([]);
  RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    _fetchFamilyData();
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
      try {
        String invitedUid = cleanInput;

        // Cek apakah input adalah email
        if (cleanInput.contains('@')) {
          final userQuery = await _firestore.collection('users').where('email', isEqualTo: cleanInput.toLowerCase()).limit(1).get();
          if (userQuery.docs.isNotEmpty) {
            invitedUid = userQuery.docs.first.id;
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
        }

        if (invitedUid == user!.uid) {
          Get.snackbar("Info", "Anda tidak dapat mengundang diri sendiri.");
          return;
        }

        List<String> updatedMembers = List<String>.from(currentFamily.value!.memberUids);
        if (!updatedMembers.contains(invitedUid)) {
          updatedMembers.add(invitedUid);
          await _firestore.collection('families').doc(currentFamily.value!.id).update({
            'memberUids': updatedMembers,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          // Also update the invited user's document to link to this family
          await _firestore.collection('users').doc(invitedUid).update({
            'familyId': currentFamily.value!.id,
            // 'isProMember': true, // This should be handled by the pro subscription logic
          });

          Get.snackbar("Success", "$cleanInput invited to family!");
          _fetchFamilyData(); // Refresh data
        } else {
          Get.snackbar("Info", "$cleanInput is already a member.");
        }
      } catch (e) {
        Get.snackbar("Error", "Failed to invite member: $e");
      }
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
}
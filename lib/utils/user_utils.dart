import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserUtils {
  static Future<String?> getCurrentUserFamilyId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return null;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        return doc.data()?['familyId'] as String?;
      }
    } catch (e) {
      print('Error getting user family ID: $e');
    }
    return null;
  }

  static Future<bool> isCurrentUserProMember() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return false;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        return doc.data()?['isProMember'] == true;
      }
    } catch (e) {
      print('Error checking pro status: $e');
    }
    return false;
  }

  static Future<List<Map<String, String>>> getFamilyMembers(String familyId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return [];
    }

    try {
      final familyDoc = await FirebaseFirestore.instance.collection('families').doc(familyId).get();
      if (familyDoc.exists) {
        final memberUids = List<String>.from(familyDoc.data()?['memberUids'] ?? []);
        List<Map<String, String>> members = [];
        for (String uid in memberUids) {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
          if (userDoc.exists) {
            members.add({
              'uid': uid,
              'name': userDoc.data()?['displayName'] ?? 'Anggota Keluarga', // Assuming 'displayName' field in user doc
            });
          }
        }
        return members;
      }
    } catch (e) {
      print('Error getting family members: $e');
    }
    return [];
  }
}
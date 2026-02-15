// This is the Javascript code for your Firebase Cloud Function.
// 1. Make sure you have the Firebase CLI installed and are in a Firebase project directory.
// 2. If you don't have a 'functions' folder, run `firebase init functions`. Choose Javascript.
// 3. Replace the content of `functions/index.js` with this code.
// 4. Install the required dependency by running `npm install firebase-admin firebase-functions` inside the `functions` directory.
// 5. Deploy the function by running `firebase deploy --only functions` from your project's root directory.

const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

/**
 * Deletes a family and all associated data.
 * This function is callable from the client.
 *
 * @param {object} data The data passed to the function.
 * @param {string} data.familyId The ID of the family to delete.
 * @param {object} context The context of the function call.
 * @param {string} context.auth.uid The UID of the authenticated user calling the function.
 */
exports.deleteFamily = functions
  .region("asia-southeast2") // IMPORTANT: Make sure this region matches your project's and client-side code's region.
  .https.onCall(async (data, context) => {
    // Check for authentication
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Pengguna harus terautentikasi untuk menghapus keluarga."
      );
    }

    const uid = context.auth.uid;
    const familyId = data.familyId;

    if (!familyId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "ID Keluarga (familyId) harus disediakan."
      );
    }

    const db = admin.firestore();
    const familyRef = db.collection("families").doc(familyId);

    try {
      const familyDoc = await familyRef.get();

      // Check if family exists
      if (!familyDoc.exists) {
        throw new functions.https.HttpsError(
          "not-found",
          "Keluarga tidak ditemukan."
        );
      }

      const familyData = familyDoc.data();

      // Security Check: Only the owner can delete the family
      if (familyData.ownerUid !== uid) {
        throw new functions.https.HttpsError(
          "permission-denied",
          "Hanya pemilik keluarga yang dapat menghapus."
        );
      }
      
      const memberUids = familyData.memberUids || [];
      const batch = db.batch();

      // 1. Delete the family document
      batch.delete(familyRef);

      // 2. Update all members to remove family link
      for (const memberUid of memberUids) {
        const userRef = db.collection("users").doc(memberUid);
        batch.update(userRef, {
          familyId: admin.firestore.FieldValue.delete(),
          isProMember: admin.firestore.FieldValue.delete(),
        });
      }

      // 3. Delete all invitations for this family
      const invitationsSnapshot = await db
        .collection("invitations")
        .where("familyId", "==", familyId)
        .get();
        
      for (const doc of invitationsSnapshot.docs) {
        batch.delete(doc.ref);
      }

      // Commit the batch
      await batch.commit();

      return { success: true, message: "Keluarga berhasil dihapus dari server." };

    } catch (error) {
      console.error("Gagal menghapus keluarga:", error);
      if (error instanceof functions.https.HttpsError) {
        throw error; // Re-throw HttpsError
      }
      throw new functions.https.HttpsError(
        "internal",
        "Terjadi kesalahan internal saat menghapus keluarga.",
        error.message
      );
    }
  });

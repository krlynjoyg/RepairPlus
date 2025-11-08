/**
 * Import function triggers from their respective submodules:
 */
const {setGlobalOptions} = require("firebase-functions");
const {onRequest} = require("firebase-functions/https");
const logger = require("firebase-functions/logger");

// v1 Auth trigger and Admin SDK
const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

// Optional: control max instances to manage costs
setGlobalOptions({maxInstances: 10});

// Example of an HTTP function (you can keep or remove this)
exports.helloWorld = onRequest((request, response) => {
  logger.info(
      "Hello logs!",
      {structuredData: true},
  );
  response.send(
      "Hello from Firebase!",
  );
});

/**
 * 🧭 Sync user displayName from Firebase Auth → Firestore automatically
 */
exports.syncUserProfileToFirestore = functions.auth.user().onUpdate(
    async (change) => {
      const before = change.before;
      const after = change.after;

      const uid = after.uid;
      const newDisplayName = after.displayName;
      const oldDisplayName = before.displayName;

      // Only update if display name changed
      if (newDisplayName !== oldDisplayName) {
        try {
          const userRef = admin.firestore().collection("users").doc(uid);
          const doc = await userRef.get();

          if (doc.exists) {
          // ✅ Update existing document
            await userRef.update({
              displayName: newDisplayName,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          } else {
          // 🆕 Create new doc if it doesn't exist
            await userRef.set({
              displayName: newDisplayName,
              email: after.email,
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          }

          console.log(`✅ Synced displayName for UID: ${uid}`);
        } catch (error) {
          console.error("❌ Error updating Firestore:", error);
        }
      } else {
        console.log(`ℹ️ No displayName change for UID: ${uid}`);
      }
    },
);

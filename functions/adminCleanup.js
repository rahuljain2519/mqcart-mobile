const { onRequest } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const BATCH_LIMIT = 450; // safe under 500

async function deleteCollection(collectionName) {
  let deletedCount = 0;

  while (true) {
    const snap = await db.collection(collectionName).limit(BATCH_LIMIT).get();
    if (snap.empty) break;

    const batch = db.batch();
    snap.docs.forEach(doc => {
      batch.delete(doc.ref);
      deletedCount++;
    });

    await batch.commit();
  }

  return deletedCount;
}

exports.cleanupMqCartTestData = onRequest(
  {
    region: 'us-central1',
    timeoutSeconds: 540,
  },
  async (req, res) => {
    try {
      const deleted = {};

      // ⚠️ ORDER MATTERS (children → parents)
      deleted.products = await deleteCollection('products');
      deleted.shops = await deleteCollection('shops');
      deleted.users = await deleteCollection('users');
      deleted.sellerApplications = await deleteCollection('seller_applications');
      deleted.societies = await deleteCollection('societies');

      return res.json({
        success: true,
        message: 'All test data cleaned successfully',
        deleted,
      });
    } catch (err) {
      console.error('Cleanup failed:', err);
      return res.status(500).json({
        success: false,
        error: err.message || 'Cleanup failed',
      });
    }
  }
);

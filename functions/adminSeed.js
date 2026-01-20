const { onRequest } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');

// ⚠️ IMPORTANT
// Do NOT call initializeApp() again if already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

exports.seedMqCartTestData = onRequest(
  {
    region: 'us-central1',
    timeoutSeconds: 540,
  },
  async (req, res) => {
    try {
      /* ----------------------------------
         1️⃣ CREATE SOCIETY
      ---------------------------------- */
      const societyRef = db.collection('societies').doc();
      const societyId = societyRef.id;

      await societyRef.set({
        name: 'MQ Cart Load Test Society',
        city: 'Bangalore',
        isActive: true,
        createdAt: new Date().toISOString(),
      });

      /* ----------------------------------
         2️⃣ CREATE SELLERS, SHOPS, PRODUCTS
      ---------------------------------- */
      for (let i = 1; i <= 10; i++) {
        // Create shop FIRST (needed for seller.shopId)
        const shopRef = db.collection('shops').doc();
        const shopId = shopRef.id;

        // Create seller (MATCHES REAL APPROVED SELLER)
        const sellerRef = db.collection('users').doc();
        const sellerId = sellerRef.id;

        await sellerRef.set({
          uid: sellerId,
          name: `Seller ${i}`,
          phone: `90000000${i}`,
          role: 'seller',
          sellerStatus: 'approved',        // 🔥 REQUIRED
          profileCompleted: true,          // 🔥 REQUIRED
          shopId: shopId,                  // 🔥 REQUIRED
          societyId: societyId,
          createdAt: new Date().toISOString(),
          updatedAt: new Date().toISOString(),
        });

        // Create shop (ACTIVE)
        await shopRef.set({
          shopId,
          sellerId,
          societyId,
          shopName: `Seller ${i} Shop`,
          description: 'Load test shop',
          logoUrl: `https://picsum.photos/200/200?random=${i}`,
          bannerUrl: `https://picsum.photos/1200/400?random=${i}`,
          address: 'Test Address',
          phone: `90000000${i}`,
          plan: 'normal',
          productLimit: 20,
          isActive: true,
          createdAt: new Date().toISOString(),
        });

        // Create 20 products per shop
        for (let p = 1; p <= 20; p++) {
          const productRef = db.collection('products').doc();
          const seed = i * 100 + p;

          await productRef.set({
            id: productRef.id,
            shopId,
            sellerId,
            societyId,
            name: `Test Product ${i}-${p}`,
            price: 100 + p,
            quantity: 100,
            category: 'general',
            description: 'Test product',
            images: [
              `https://picsum.photos/600/600?random=${seed}`,
              `https://picsum.photos/600/600?random=${seed + 1}`,
            ],
            coverImage: `https://picsum.photos/600/600?random=${seed}`,
            isActive: true,
            createdAt: new Date().toISOString(),
          });
        }
      }

      return res.json({
        success: true,
        message: 'MQ Cart test data created with APPROVED sellers',
      });
    } catch (err) {
      console.error('Seeding failed:', err);
      return res.status(500).json({ error: 'Seeding failed' });
    }
  }
);

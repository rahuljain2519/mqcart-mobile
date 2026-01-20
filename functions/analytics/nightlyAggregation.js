const admin = require("firebase-admin");
const { onSchedule } = require("firebase-functions/v2/scheduler");

const db = admin.firestore();

exports.nightlyAggregation = onSchedule(
  {
    schedule: "0 2 * * *", // 2 AM daily
    timeZone: "Asia/Kolkata",
  },
  async () => {
    const now = admin.firestore.FieldValue.serverTimestamp();

    const today = new Date();
    const startDate = new Date();
    startDate.setDate(today.getDate() - 30);

    // Reset overview month counters
    const overviewRef = db.doc("analytics_overview/current");
    await overviewRef.set(
      {
        ordersToday: 0,
        gmvToday: 0,
        ordersMonth: 0,
        gmvMonth: 0,
        lastUpdatedAt: now,
      },
      { merge: true }
    );

    const ordersSnap = await db
      .collection("orders")
      .where("status", "==", "completed")
      .where("createdAt", ">=", startDate)
      .get();

    const batch = db.batch();

    ordersSnap.forEach((doc) => {
      const order = doc.data();

      const {
        sellerId,
        buyerId,
        societyId,
        totalAmount,
        items,
        createdAt,
      } = order;

      const dateKey = createdAt.toDate().toISOString().slice(0, 10);

      // 🔹 Overview
      batch.set(
        overviewRef,
        {
          ordersMonth: admin.firestore.FieldValue.increment(1),
          gmvMonth: admin.firestore.FieldValue.increment(totalAmount),
        },
        { merge: true }
      );

      // 🔹 Daily Orders
      batch.set(
        db.doc(`analytics_orders/${dateKey}`),
        {
          date: dateKey,
          orders: admin.firestore.FieldValue.increment(1),
          gmv: admin.firestore.FieldValue.increment(totalAmount),
          lastUpdatedAt: now,
        },
        { merge: true }
      );

      // 🔹 Seller
      batch.set(
        db.doc(`analytics_sellers/${sellerId}`),
        {
          sellerId,
          societyId,
          orders30d: admin.firestore.FieldValue.increment(1),
          revenue30d: admin.firestore.FieldValue.increment(totalAmount),
          lastOrderAt: now,
        },
        { merge: true }
      );

      // 🔹 Buyer
      batch.set(
        db.doc(`analytics_buyers/${buyerId}`),
        {
          buyerId,
          societyId,
          orders30d: admin.firestore.FieldValue.increment(1),
          totalSpend30d: admin.firestore.FieldValue.increment(totalAmount),
          lastActiveAt: now,
        },
        { merge: true }
      );

      // 🔹 Products
      if (Array.isArray(items)) {
        items.forEach((item) => {
          batch.set(
            db.doc(`analytics_products/${item.productId}`),
            {
              productId: item.productId,
              orders30d: admin.firestore.FieldValue.increment(item.qty),
              revenue30d: admin.firestore.FieldValue.increment(
                item.price * item.qty
              ),
              lastSoldAt: now,
            },
            { merge: true }
          );
        });
      }

      // 🔹 Society
      batch.set(
        db.doc(`analytics_societies/${societyId}`),
        {
          societyId,
          orders30d: admin.firestore.FieldValue.increment(1),
          revenue30d: admin.firestore.FieldValue.increment(totalAmount),
          lastOrderAt: now,
        },
        { merge: true }
      );
    });

    await batch.commit();
  }
);

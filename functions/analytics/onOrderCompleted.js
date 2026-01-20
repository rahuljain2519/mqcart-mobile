const admin = require("firebase-admin");
const { onDocumentUpdated } = require("firebase-functions/v2/firestore");

const db = admin.firestore();

exports.onOrderCompleted = onDocumentUpdated(
  "orders/{orderId}",
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();

    // ✅ YOUR ACTUAL STATUS
    if (before.status === "delivered" || after.status !== "delivered") {
      return;
    }

    const {
      sellerId,
      societyId,
      totalAmount,
      updatedAt,
    } = after;

    const items = after["0"] ? [after["0"]] : [];

    const date = updatedAt.toDate();
    const todayKey = date.toISOString().slice(0, 10);
    const now = admin.firestore.FieldValue.serverTimestamp();

    const batch = db.batch();

    /* =========================
       OVERVIEW
    ========================= */
    batch.set(
      db.doc("analytics_overview/current"),
      {
        ordersToday: admin.firestore.FieldValue.increment(1),
        ordersMonth: admin.firestore.FieldValue.increment(1),
        gmvToday: admin.firestore.FieldValue.increment(totalAmount),
        gmvMonth: admin.firestore.FieldValue.increment(totalAmount),
        lastUpdatedAt: now,
      },
      { merge: true }
    );

    /* =========================
       DAILY ORDERS
    ========================= */
    batch.set(
      db.doc(`analytics_orders/${todayKey}`),
      {
        date: todayKey,
        orders: admin.firestore.FieldValue.increment(1),
        gmv: admin.firestore.FieldValue.increment(totalAmount),
        lastUpdatedAt: now,
      },
      { merge: true }
    );

    /* =========================
       SELLER
    ========================= */
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

    /* =========================
       PRODUCTS
    ========================= */
    items.forEach((item) => {
      batch.set(
        db.doc(`analytics_products/${item.productId}`),
        {
          productId: item.productId,
          orders30d: admin.firestore.FieldValue.increment(item.quantity),
          revenue30d: admin.firestore.FieldValue.increment(
            item.price * item.quantity
          ),
          lastSoldAt: now,
        },
        { merge: true }
      );
    });

    /* =========================
       SOCIETY
    ========================= */
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

    await batch.commit();
  }
);

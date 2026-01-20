const functions = require("firebase-functions"); 
const admin = require("firebase-admin");
const crypto = require("crypto");
const Razorpay = require("razorpay");
const { defineSecret } = require("firebase-functions/params");

admin.initializeApp();
const db = admin.firestore();

/* =========================================================
   🔐 SECRETS (firebase-functions v7)
   ========================================================= */

const RAZORPAY_KEY_ID = defineSecret("RAZORPAY_KEY_ID");
const RAZORPAY_KEY_SECRET = defineSecret("RAZORPAY_KEY_SECRET");
const RAZORPAY_WEBHOOK_SECRET = defineSecret("RAZORPAY_WEBHOOK_SECRET");

/* =========================================================
   🧠 Razorpay client (runtime only)
   ========================================================= */
function getRazorpayClient() {
  return new Razorpay({
    key_id: RAZORPAY_KEY_ID.value(),
    key_secret: RAZORPAY_KEY_SECRET.value(),
  });
}

/* =========================================================
   1️⃣ CREATE RAZORPAY ORDER (CALLABLE)
   ========================================================= */
const { onCall, HttpsError } = require("firebase-functions/v2/https");

exports.createSellerOrder = onCall(
  {
    secrets: [
      RAZORPAY_KEY_ID,
      RAZORPAY_KEY_SECRET,
    ],
  },
  async (request) => {
    const { paymentDocId } = request.data || {};

    if (!paymentDocId) {
      throw new HttpsError(
        "invalid-argument",
        "paymentDocId is required"
      );
    }

    const paymentRef = db
      .collection("seller_activation_payments")
      .doc(paymentDocId);

    const snap = await paymentRef.get();

    if (!snap.exists) {
      throw new HttpsError(
        "not-found",
        "Payment record not found"
      );
    }

    const { monthlyFee } = snap.data();

    if (typeof monthlyFee !== "number" || monthlyFee <= 0) {
      throw new HttpsError(
        "failed-precondition",
        "Invalid monthlyFee in payment record"
      );
    }

    const razorpay = getRazorpayClient();

    const order = await razorpay.orders.create({
      amount: monthlyFee * 100,
      currency: "INR",
      payment_capture: 1,
    });

    await paymentRef.update({
      razorpayOrderId: order.id,
      status: "order_created",
      orderCreatedAt:
        admin.firestore.FieldValue.serverTimestamp(),
    });

    return { orderId: order.id };
  }
);


/* =========================================================
   2️⃣ RAZORPAY WEBHOOK (FINAL AUTHORITY)
   ========================================================= */

  const { onRequest } = require("firebase-functions/v2/https");

exports.razorpayWebhook = onRequest(
  {
    secrets: [RAZORPAY_WEBHOOK_SECRET],
  },
  async (req, res) => {
    const receivedSignature = req.headers["x-razorpay-signature"];

    const expectedSignature = crypto
      .createHmac("sha256", RAZORPAY_WEBHOOK_SECRET.value())
      .update(req.rawBody) // 🔥 REQUIRED
      .digest("hex");

    if (receivedSignature !== expectedSignature) {
      console.error("Invalid Razorpay webhook signature");
      return res.status(401).send("Invalid signature");
    }

    if (req.body.event === "payment.captured") {
      const payment = req.body.payload.payment.entity;
      const razorpayOrderId = payment.order_id;

      const snap = await db
        .collection("seller_activation_payments")
        .where("razorpayOrderId", "==", razorpayOrderId)
        .limit(1)
        .get();

      if (snap.empty) return res.sendStatus(200);

      const paymentDoc = snap.docs[0];
      const paymentData = paymentDoc.data();

      if (paymentData.status === "completed") {
        return res.sendStatus(200);
      }

      const { shopId, plan, productLimit } = paymentData;

      await db.collection("shops").doc(shopId).update({
        isActive: true,
        plan,
        planStatus: "active",
        productLimit,
        planActivatedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      await paymentDoc.ref.update({
        status: "completed",
        razorpayPaymentId: payment.id,
        capturedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      const sellerId = paymentData.sellerId;

      const now = admin.firestore.Timestamp.now();
     const plansSnap = await db
        .collection("platform_config")
        .doc("seller_plans")
        .get();

      const validityDays =
        plansSnap.data()?.[plan]?.validityDays ?? 30; // fallback

      const expiry = admin.firestore.Timestamp.fromDate(
        new Date(Date.now() + validityDays * 24 * 60 * 60 * 1000)
      );

      await db
        .collection("seller_subscriptions")
        .doc(sellerId)
        .set({
          sellerId,
          shopId,

          currentPlan: plan,          // basic | pro | elite
          status: "active",

          productLimit,

          startedAt: now,
          expiresAt: expiry,

          autoRenew: true,
          freePlanUsed: true,

          lastPaymentId: payment.id,

          updatedAt: now,
        }, { merge: true });

      console.log("SHOP ACTIVATED VIA WEBHOOK", { shopId, plan });
    }

    return res.sendStatus(200);
  }
);

const { onDocumentUpdated } = require("firebase-functions/v2/firestore");
exports.enforceProductLimitOnPlanChange = onDocumentUpdated(
  "shops/{shopId}",
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    const shopId = event.params.shopId;

    if (!before || !after) return;

    // Only enforce when productLimit is reduced
    if (
      typeof before.productLimit !== "number" ||
      typeof after.productLimit !== "number" ||
      after.productLimit >= before.productLimit
    ) {
      return;
    }

    const newLimit = after.productLimit;

    console.log("ENFORCING PRODUCT LIMIT", {
      shopId,
      from: before.productLimit,
      to: newLimit,
    });

    const productsSnap = await db
      .collection("products")
      .where("shopId", "==", shopId)
      .where("isActive", "==", true)
      .get();

    if (productsSnap.size <= newLimit) {
      console.log("NO ENFORCEMENT NEEDED");
      return;
    }

    const batch = db.batch();
    const excessProducts = productsSnap.docs.slice(newLimit);

    excessProducts.forEach((doc) => {
      batch.update(doc.ref, { isActive: false });
    });

    await batch.commit();

    console.log("PRODUCTS DEACTIVATED", excessProducts.length);
  }
);

const { onDocumentCreated } = require("firebase-functions/v2/firestore");

exports.notifySellerOnNewOrder = onDocumentCreated(
  "orders/{orderId}",
  async (event) => {
    const order = event.data?.data();
    if (!order) return;

    const sellerUid = order.sellerId; // sellerId = user.uid in your system
    if (!sellerUid) return;

    const userSnap = await admin
      .firestore()
      .collection("users")
      .doc(sellerUid)
      .get();

    if (!userSnap.exists) return;

    const user = userSnap.data();
    if (user.role !== "seller") return;
    if (!user.fcmToken) return;

    const payload = {
      notification: {
        title: "🔔 New Order Received",
        body: `Order ${event.params.orderId} • ₹${order.totalAmount}`,
      },
      data: {
        type: "NEW_ORDER",
        orderId: event.params.orderId,
      },
    };

    await admin.messaging().sendToDevice(
      user.fcmToken,
      payload
    );
  }
);

exports.onOrderCompleted = require("./analytics/onOrderCompleted").onOrderCompleted;
exports.nightlyAggregation = require("./analytics/nightlyAggregation").nightlyAggregation;
exports.seedMqCartTestData = require('./adminSeed').seedMqCartTestData;
exports.cleanupMqCartTestData = require('./adminCleanup').cleanupMqCartTestData;




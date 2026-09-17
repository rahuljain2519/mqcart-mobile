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
   📦 Stock arithmetic — Node port of lib/core/stock_delta.dart
   (groupByProduct / applyStockDelta), used by the buyer-order-payment
   webhook branch to reduce stock server-side once a payment is
   captured. Unlike the Dart client version, this never throws on
   insufficient stock (clamps to 0 instead) — the buyer has already
   paid by the time this runs, so the order must still be created;
   losing an order after a real payment would be worse than an
   occasional oversold item.
   ========================================================= */
function groupByProductId(items) {
  const grouped = {};
  for (const item of items) {
    (grouped[item.productId] ||= []).push(item);
  }
  return grouped;
}

function applyStockDelta(data, lines, sign) {
  const rawOptions = data.options;
  if (Array.isArray(rawOptions) && rawOptions.length > 0) {
    const options = rawOptions.map((o) => ({ ...o }));
    for (const line of lines) {
      const idx = options.findIndex((o) => o.name === line.optionName);
      if (idx < 0) continue;
      const next = (options[idx].quantity || 0) + sign * line.quantity;
      options[idx].quantity = next < 0 ? 0 : next;
    }
    const total = options.reduce((s, o) => s + (o.quantity || 0), 0);
    return { options, quantity: total };
  }

  const totalQty = lines.reduce((s, l) => s + l.quantity, 0);
  const next = (data.quantity || 0) + sign * totalQty;
  return { quantity: next < 0 ? 0 : next };
}

/* =========================================================
   1️⃣c BUYER ORDER PAYMENT — webhook branch
   Second lookup the webhook falls through to when a captured payment's
   razorpayOrderId doesn't match a seller_activation_payments doc. Mirrors
   that flow's idempotency guard, then creates the real `orders/{orderId}`
   doc (using the id pre-generated client-side and stored on the payment
   doc) and reduces stock — this is the FIRST time the order doc is
   written for an online-payment order (unlike COD, where the client
   writes it immediately at checkout), so notifySellerOnNewOrder
   naturally only fires once payment is actually captured.
   ========================================================= */
async function handleBuyerOrderPaymentCaptured(razorpayOrderId, payment, res) {
  const snap = await db
    .collection("buyer_order_payments")
    .where("razorpayOrderId", "==", razorpayOrderId)
    .limit(1)
    .get();

  if (snap.empty) return res.sendStatus(200);

  const paymentDoc = snap.docs[0];
  const paymentData = paymentDoc.data();

  if (paymentData.status === "completed") {
    return res.sendStatus(200);
  }

  const {
    orderId,
    items,
    buyerId,
    sellerId,
    societyId,
    flatNumber,
    societyName,
    shopName,
    shopPhone,
    totalAmount,
  } = paymentData;

  await db.runTransaction(async (tx) => {
    const grouped = groupByProductId(items);
    const productIds = Object.keys(grouped);
    const productRefs = productIds.map((id) => db.collection("products").doc(id));
    const productSnaps = await Promise.all(productRefs.map((ref) => tx.get(ref)));

    const patches = productIds.map((id, i) => {
      const productSnap = productSnaps[i];
      if (!productSnap.exists) return null;
      return applyStockDelta(productSnap.data(), grouped[id], -1);
    });

    productRefs.forEach((ref, i) => {
      if (patches[i]) tx.update(ref, patches[i]);
    });

    tx.set(db.collection("orders").doc(orderId), {
      buyerId,
      sellerId,
      societyId,
      flatNumber,
      societyName,
      shopName,
      shopPhone,
      items,
      totalAmount,
      status: "placed",
      paymentMethod: "razorpay",
      paymentStatus: "paid",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    tx.update(paymentDoc.ref, {
      status: "completed",
      razorpayPaymentId: payment.id,
      capturedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  console.log("BUYER ORDER PLACED VIA WEBHOOK", { orderId, buyerId });
  return res.sendStatus(200);
}

const { onCall, HttpsError } = require("firebase-functions/v2/https");

/* =========================================================
   1️⃣ CREATE RAZORPAY ORDER (CALLABLE)
   ========================================================= */
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
   1️⃣b CREATE BUYER ORDER RAZORPAY ORDER (CALLABLE)
   Mirrors createSellerOrder above. amount is server-derived from the
   buyer_order_payments doc, never trusted from the client directly.
   Note: like the seller flow, totalAmount on that doc is itself
   client-supplied at creation time and not re-validated here against
   live product prices/stock - same trust model as the existing seller
   activation flow, not a new regression. A future hardening could
   recompute totalAmount from live product data before creating the
   Razorpay order.
   ========================================================= */
exports.createBuyerOrderPayment = onCall(
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
      .collection("buyer_order_payments")
      .doc(paymentDocId);

    const snap = await paymentRef.get();

    if (!snap.exists) {
      throw new HttpsError(
        "not-found",
        "Payment record not found"
      );
    }

    const { totalAmount } = snap.data();

    if (typeof totalAmount !== "number" || totalAmount <= 0) {
      throw new HttpsError(
        "failed-precondition",
        "Invalid totalAmount in payment record"
      );
    }

    const razorpay = getRazorpayClient();

    const order = await razorpay.orders.create({
      amount: Math.round(totalAmount * 100),
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

      if (snap.empty) {
        return handleBuyerOrderPaymentCaptured(razorpayOrderId, payment, res);
      }

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

    // Collect every registered device: legacy single `fcmToken` (mobile today)
    // plus the `fcmTokens` map { token: platform } used by web and newer mobile.
    const tokens = new Set();
    if (user.fcmToken) tokens.add(user.fcmToken);
    if (user.fcmTokens && typeof user.fcmTokens === "object") {
      Object.keys(user.fcmTokens).forEach((t) => t && tokens.add(t));
    }
    if (tokens.size === 0) return;

    const tokenList = [...tokens];

    const res = await admin.messaging().sendEachForMulticast({
      tokens: tokenList,
      notification: {
        title: "🔔 New Order Received",
        body: `Order ${event.params.orderId} • ₹${order.totalAmount}`,
      },
      data: {
        type: "NEW_ORDER",
        orderId: event.params.orderId,
      },
    });

    // Prune tokens the FCM backend reports as permanently invalid.
    const dead = [];
    res.responses.forEach((r, i) => {
      const code = r.error && r.error.code;
      if (
        !r.success &&
        (code === "messaging/registration-token-not-registered" ||
          code === "messaging/invalid-registration-token" ||
          code === "messaging/invalid-argument")
      ) {
        dead.push(tokenList[i]);
      }
    });
    if (dead.length) {
      const upd = {};
      dead.forEach((t) => {
        upd[`fcmTokens.${t}`] = admin.firestore.FieldValue.delete();
      });
      if (dead.includes(user.fcmToken)) {
        upd.fcmToken = admin.firestore.FieldValue.delete();
      }
      await userSnap.ref.update(upd).catch(() => {});
    }
  }
);

exports.onOrderCompleted = require("./analytics/onOrderCompleted").onOrderCompleted;
exports.nightlyAggregation = require("./analytics/nightlyAggregation").nightlyAggregation;
exports.seedMqCartTestData = require('./adminSeed').seedMqCartTestData;
exports.cleanupMqCartTestData = require('./adminCleanup').cleanupMqCartTestData;




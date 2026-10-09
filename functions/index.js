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

    const { totalAmount, shopId } = snap.data();

    if (typeof totalAmount !== "number" || totalAmount <= 0) {
      throw new HttpsError(
        "failed-precondition",
        "Invalid totalAmount in payment record"
      );
    }

    const razorpay = getRazorpayClient();
    const amountPaise = Math.round(totalAmount * 100);
    const orderPayload = {
      amount: amountPaise,
      currency: "INR",
      payment_capture: 1,
    };

    // Seller settlement (Route): if this shop has an activated Razorpay
    // linked account, split the payment automatically at capture time so
    // the seller's share lands directly in their own bank account - no
    // manual transfer, no batch job. Shops without an activated account
    // keep today's behavior unchanged (full amount stays in MQ Cart's
    // account) rather than blocking online payment outright.
    if (shopId) {
      const shopSnap = await db.collection("shops").doc(shopId).get();
      const shop = shopSnap.data();
      if (shop?.razorpayAccountId && shop?.routeStatus === "activated") {
        orderPayload.transfers = [
          {
            account: shop.razorpayAccountId,
            amount: amountPaise, // commission deduction TBD - currently 100% to seller
            currency: "INR",
            on_hold: false,
          },
        ];
      }
    }

    const order = await razorpay.orders.create(orderPayload);

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

/* =========================================================
   4️⃣ ADMIN: FULLY DELETE A SELLER (CALLABLE, ADMIN ONLY)
   Irreversible. Resets users/{uid} back to a plain buyer and removes
   every seller-specific doc/file: shop(s) + their products (Firestore
   and Storage images), seller_applications, seller_subscriptions,
   seller_activation_payments (client can't delete these directly - rules
   have allow delete: if false - this function is exactly why it's a
   Cloud Function), and the societies/{societyId}/sellers KYC doc + its
   Storage files.

   Deliberately NOT touched: `orders` (historical transactions involving
   other people - shouldn't vanish retroactively) and
   `buyer_order_payments` (this uid's own purchases AS A BUYER, unrelated
   to their seller identity).
   ========================================================= */
async function deleteFirestoreDocsInChunks(refs) {
  for (let i = 0; i < refs.length; i += 400) {
    const chunk = refs.slice(i, i + 400);
    const batch = db.batch();
    chunk.forEach((ref) => batch.delete(ref));
    await batch.commit();
  }
}

exports.adminDeleteSeller = onCall(async (request) => {
  const callerUid = request.auth?.uid;
  if (!callerUid) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }

  const callerSnap = await db.collection("users").doc(callerUid).get();
  if (!callerSnap.exists || callerSnap.data().role !== "admin") {
    throw new HttpsError("permission-denied", "Admin only.");
  }

  const { uid } = request.data || {};
  if (!uid) {
    throw new HttpsError("invalid-argument", "uid is required.");
  }

  const userRef = db.collection("users").doc(uid);
  const userSnap = await userRef.get();
  if (!userSnap.exists) {
    throw new HttpsError("not-found", "User not found.");
  }
  const societyId = userSnap.data().societyId || null;

  const bucket = admin.storage().bucket();

  // 1️⃣ Shop(s) + their products (Firestore + Storage)
  const shopsSnap = await db.collection("shops").where("sellerId", "==", uid).get();
  for (const shopDoc of shopsSnap.docs) {
    const shopId = shopDoc.id;

    const productsSnap = await db
      .collection("products")
      .where("shopId", "==", shopId)
      .get();
    await deleteFirestoreDocsInChunks(productsSnap.docs.map((d) => d.ref));

    await bucket.deleteFiles({ prefix: `products/${shopId}/` }).catch(() => {});
    await bucket.deleteFiles({ prefix: `shops/${shopId}/` }).catch(() => {});

    await shopDoc.ref.delete();
  }

  // 2️⃣ seller_applications
  await db.collection("seller_applications").doc(uid).delete().catch(() => {});

  // 3️⃣ seller_subscriptions
  await db.collection("seller_subscriptions").doc(uid).delete().catch(() => {});

  // 4️⃣ seller_activation_payments (client can't delete these - rules block it)
  const paymentsSnap = await db
    .collection("seller_activation_payments")
    .where("sellerId", "==", uid)
    .get();
  await deleteFirestoreDocsInChunks(paymentsSnap.docs.map((d) => d.ref));

  // 5️⃣ societies/{societyId}/sellers/{uid} KYC doc + its Storage files
  if (societyId) {
    await db
      .collection("societies")
      .doc(societyId)
      .collection("sellers")
      .doc(uid)
      .delete()
      .catch(() => {});
    await bucket
      .deleteFiles({ prefix: `seller_documents/${societyId}/${uid}/` })
      .catch(() => {});
  }

  // 6️⃣ Reset the user back to a plain buyer (not deleted - they keep their
  // account, name, phone, society/flat).
  await userRef.update({
    role: "buyer",
    sellerStatus: "none",
    shopId: null,
    approvedAt: admin.firestore.FieldValue.delete(),
    rejectedAt: admin.firestore.FieldValue.delete(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  console.log("SELLER DELETED BY ADMIN", { uid, admin: callerUid });

  return { success: true };
});

/* =========================================================
   💸 SELLER SETTLEMENT (RAZORPAY ROUTE)
   Lets a seller's share of an online order move to their own bank
   account automatically at payment-capture time, instead of sitting
   in MQ Cart's Razorpay balance with no way out. Two admin-triggered
   steps (one-time per seller) plus an automatic step (every payment):

   1️⃣ createSellerRouteAccount — admin-only, one-time. Creates a
      Razorpay "linked account" (Route) for the seller using the KYC
      data already collected at seller_applications/{uid} (business
      type, PAN, address, bank details) plus an email the seller adds
      themselves in Shop Settings (Route requires one; nothing else
      in this app collects email). Razorpay then reviews the account
      (can take a few days) before it's usable for transfers.

   2️⃣ refreshSellerRouteStatus — admin-only. Polls Razorpay for the
      account's current Route activation status and updates the shop
      doc. (No webhook listener for account.activated yet - this is
      the simpler v1; a webhook can replace the manual refresh later
      without changing anything else.)

   3️⃣ createBuyerOrderPayment (existing function, modified below) —
      once a shop has an activated Route account, every subsequent
      online order automatically includes a `transfers` entry so
      Razorpay splits the payment at capture time. Until then,
      behavior is UNCHANGED from before this feature existed (full
      amount stays in MQ Cart's account) - this was a deliberate
      choice to avoid silently disabling online payment for every
      existing seller the moment this ships.
   ========================================================= */

const ROUTE_BUSINESS_TYPE_MAP = {
  "Individual": "individual",
  "Proprietorship": "proprietorship",
  "Partnership": "partnership",
  "Private Limited": "private_limited",
  "LLP": "llp",
};

exports.createSellerRouteAccount = onCall(
  { secrets: [RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET] },
  async (request) => {
    const callerUid = request.auth?.uid;
    if (!callerUid) throw new HttpsError("unauthenticated", "Sign in required.");

    const callerSnap = await db.collection("users").doc(callerUid).get();
    if (!callerSnap.exists || callerSnap.data().role !== "admin") {
      throw new HttpsError("permission-denied", "Admin only.");
    }

    const { uid } = request.data || {};
    if (!uid) throw new HttpsError("invalid-argument", "uid is required.");

    const [userSnap, appSnap, shopSnap] = await Promise.all([
      db.collection("users").doc(uid).get(),
      db.collection("seller_applications").doc(uid).get(),
      db.collection("shops").where("sellerId", "==", uid).limit(1).get(),
    ]);
    if (!userSnap.exists) throw new HttpsError("not-found", "Seller not found.");
    if (!appSnap.exists) {
      throw new HttpsError("failed-precondition", "No seller application on file.");
    }
    if (shopSnap.empty) throw new HttpsError("failed-precondition", "Seller has no shop yet.");

    const user = userSnap.data();
    const app = appSnap.data();
    const shopDoc = shopSnap.docs[0];
    const shop = shopDoc.data();

    if (!shop.email) {
      throw new HttpsError(
        "failed-precondition",
        "Seller must add an email in Shop Settings before a Razorpay account can be created."
      );
    }
    if (!app.bankAccountNumber || !app.ifscCode) {
      throw new HttpsError(
        "failed-precondition",
        "Seller's application is missing bank account number / IFSC."
      );
    }
    if (!app.panNumber) {
      throw new HttpsError("failed-precondition", "Seller's application is missing a PAN number.");
    }

    const businessType = ROUTE_BUSINESS_TYPE_MAP[app.businessType] || "individual";
    const tenDigitPhone = String(user.phone || "").replace(/\D/g, "").slice(-10);
    const razorpay = getRazorpayClient();

    let account;
    try {
      account = await razorpay.accounts.create({
        email: shop.email,
        phone: tenDigitPhone,
        type: "standard",
        business_type: businessType,
        legal_business_name: app.shopName || shop.shopName,
        customer_facing_business_name: shop.shopName,
        contact_name: user.name || shop.shopName,
        profile: {
          category: "ecommerce",
          subcategory: "grocery_stores",
          addresses: {
            registered: {
              street1: app.addressLine || shop.address || "NA",
              street2: "",
              city: app.city || "NA",
              state: app.state || "NA",
              postal_code: app.pincode || "000000",
              country: "IN",
            },
          },
        },
        legal_info: {
          pan: app.panNumber,
          ...(app.gstin ? { gst: app.gstin } : {}),
          ...(app.registrationNumber ? { cin: app.registrationNumber } : {}),
        },
      });
    } catch (err) {
      console.error("ROUTE ACCOUNT CREATE FAILED", uid, err?.error || err);
      throw new HttpsError(
        "internal",
        "Razorpay rejected the account: " + (err?.error?.description || err.message)
      );
    }

    // Individual/Proprietorship need a stakeholder (the person themselves);
    // registered-entity types still accept one and it's required either way
    // for Route to proceed to the product-configuration step.
    try {
      await razorpay.stakeholders.create(account.id, {
        name: user.name || shop.shopName,
        email: shop.email,
        kyc: { pan: app.panNumber },
        phone: { primary: tenDigitPhone },
      });
    } catch (err) {
      console.error("ROUTE STAKEHOLDER CREATE FAILED", uid, err?.error || err);
      // Don't abort - the account exists and can be retried/fixed from the
      // Razorpay dashboard directly; surfacing this as a warning, not fatal,
      // keeps the account id we already have instead of losing it.
    }

    let productId = null;
    let routeStatus = "pending";
    try {
      const product = await razorpay.products.requestProductConfiguration(account.id, {
        product_name: "route",
        tnc_accepted: true,
      });
      productId = product.id;

      await razorpay.products.edit(account.id, productId, {
        settlements: {
          account_number: app.bankAccountNumber,
          ifsc_code: app.ifscCode,
          beneficiary_name: app.bankName || user.name || shop.shopName,
        },
      });
    } catch (err) {
      console.error("ROUTE PRODUCT CONFIG FAILED", uid, err?.error || err);
      routeStatus = "needs_attention";
    }

    await shopDoc.ref.update({
      razorpayAccountId: account.id,
      razorpayRouteProductId: productId,
      routeStatus,
      routeRequestedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log("ROUTE ACCOUNT CREATED", { uid, accountId: account.id, routeStatus });
    return { accountId: account.id, routeStatus };
  }
);

exports.refreshSellerRouteStatus = onCall(
  { secrets: [RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET] },
  async (request) => {
    const callerUid = request.auth?.uid;
    if (!callerUid) throw new HttpsError("unauthenticated", "Sign in required.");

    const callerSnap = await db.collection("users").doc(callerUid).get();
    if (!callerSnap.exists || callerSnap.data().role !== "admin") {
      throw new HttpsError("permission-denied", "Admin only.");
    }

    const { uid } = request.data || {};
    if (!uid) throw new HttpsError("invalid-argument", "uid is required.");

    const shopSnap = await db.collection("shops").where("sellerId", "==", uid).limit(1).get();
    if (shopSnap.empty) throw new HttpsError("not-found", "Seller has no shop.");
    const shopDoc = shopSnap.docs[0];
    const shop = shopDoc.data();
    if (!shop.razorpayAccountId || !shop.razorpayRouteProductId) {
      throw new HttpsError("failed-precondition", "No Razorpay Route account on file yet.");
    }

    const razorpay = getRazorpayClient();
    let product;
    try {
      product = await razorpay.products.fetch(shop.razorpayAccountId, shop.razorpayRouteProductId);
    } catch (err) {
      console.error("ROUTE STATUS FETCH FAILED", uid, err?.error || err);
      throw new HttpsError(
        "internal",
        "Could not fetch status from Razorpay: " + (err?.error?.description || err.message)
      );
    }

    // Razorpay reports per-product activation as "activation_status":
    // "activated" | "under_review" | "needs_clarification" | "rejected".
    const routeStatus = product.activation_status || "pending";

    await shopDoc.ref.update({
      routeStatus,
      routeActivatedAt:
        routeStatus === "activated" ? admin.firestore.FieldValue.serverTimestamp() : null,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { routeStatus };
  }
);

exports.onOrderCompleted = require("./analytics/onOrderCompleted").onOrderCompleted;
exports.nightlyAggregation = require("./analytics/nightlyAggregation").nightlyAggregation;
exports.seedMqCartTestData = require('./adminSeed').seedMqCartTestData;
exports.cleanupMqCartTestData = require('./adminCleanup').cleanupMqCartTestData;




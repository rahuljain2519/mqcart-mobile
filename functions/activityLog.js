/* =========================================================
   📋 ACTIVITY LOG (Phase 1)
   Audit trail of meaningful account actions, one Firestore doc per event
   at users/{actorId}/activity/{logId}. Lives under the ACTOR (whoever
   performed the action), not the subject, so "logs for actions by each
   user" reads literally — everything in a user's own activity
   subcollection is something THEY did.

   Deliberately server-side only (Cloud Function triggers + a couple of
   inline calls from existing callable functions) rather than client-side
   logActivity() calls sprinkled through web/mobile/iOS:
     - Written ONCE here, automatically covers all three client codebases
       instead of needing the same call added in triplicate.
     - Not bypassable by a modified client - firestore.rules blocks all
       client writes to this subcollection, only the Admin SDK can write
       here, so the trail is trustworthy for dispute resolution.

   Trade-off accepted for Phase 1: a bulk product upload produces one
   "product.added" entry per row (no special-cased batch summary yet) -
   deferred rather than adding client-side tagging for one edge case.
   ========================================================= */

const admin = require("firebase-admin");
const { onDocumentCreated, onDocumentUpdated, onDocumentWritten } =
  require("firebase-functions/v2/firestore");

/** Appends one entry to users/{actorId}/activity. Used both by the
 *  triggers below and inline from index.js (adminDeleteSeller,
 *  razorpayWebhook) for actions that already run server-side. */
async function logActivity({ actorId, action, targetType, targetId, metadata }) {
  if (!actorId) {
    console.warn("logActivity: no actorId, skipping", { action, targetType, targetId });
    return;
  }
  await admin
    .firestore()
    .collection("users")
    .doc(actorId)
    .collection("activity")
    .add({
      action,
      targetType,
      targetId,
      metadata: metadata || {},
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
}

/* --------------------------------------------------------
   ORDERS — placed (buyer), then accepted/rejected/delivered
   (seller) or cancelled (buyer).
   -------------------------------------------------------- */

const logOrderPlaced = onDocumentCreated("orders/{orderId}", async (event) => {
  const order = event.data?.data();
  if (!order) return;

  await logActivity({
    actorId: order.buyerId,
    action: "order.placed",
    targetType: "order",
    targetId: event.params.orderId,
    metadata: {
      shopName: order.shopName || null,
      totalAmount: order.totalAmount ?? null,
      paymentMethod: order.paymentMethod || null,
    },
  });
});

const ORDER_STATUS_EVENTS = {
  accepted: (after) => ({ actorId: after.sellerId, action: "order.accepted" }),
  delivered: (after) => ({ actorId: after.sellerId, action: "order.delivered" }),
  rejected: (after) => ({
    actorId: after.sellerId,
    action: "order.rejected",
    metadata: { reason: after.rejectionReason || null },
  }),
  cancelled: (after) => ({ actorId: after.buyerId, action: "order.cancelled" }),
};

const logOrderStatusChange = onDocumentUpdated("orders/{orderId}", async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  if (!before || !after || before.status === after.status) return;

  const build = ORDER_STATUS_EVENTS[after.status];
  if (!build) return;
  const entry = build(after);

  await logActivity({
    actorId: entry.actorId,
    action: entry.action,
    targetType: "order",
    targetId: event.params.orderId,
    metadata: {
      shopName: after.shopName || null,
      totalAmount: after.totalAmount ?? null,
      ...(entry.metadata || {}),
    },
  });
});

/* --------------------------------------------------------
   SELLER APPLICATIONS — submitted (applicant), then approved/
   rejected (admin, via decidedBy) or bank details added/changed
   (the applicant themselves, from Shop Settings).
   -------------------------------------------------------- */

const logSellerApplicationSubmitted = onDocumentCreated(
  "seller_applications/{uid}",
  async (event) => {
    const app = event.data?.data();
    if (!app) return;

    await logActivity({
      actorId: event.params.uid,
      action: "seller.application_submitted",
      targetType: "seller_application",
      targetId: event.params.uid,
      metadata: { shopName: app.shopName || null },
    });
  }
);

const logSellerApplicationDecision = onDocumentUpdated(
  "seller_applications/{uid}",
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    const uid = event.params.uid;
    if (!before || !after) return;

    const statusChanged = before.status !== after.status;
    const decided =
      statusChanged &&
      (after.status === "approved" || after.status === "rejected") &&
      after.decidedBy;

    if (decided) {
      await logActivity({
        actorId: after.decidedBy,
        action: after.status === "approved" ? "seller.approved" : "seller.rejected",
        targetType: "seller_application",
        targetId: uid,
        metadata: { shopName: after.shopName || null },
      });
      return;
    }

    // Seller added/updated their own bank details (Shop Settings) -
    // separate from the admin decision above, same document.
    const bankChanged =
      before.bankAccountNumber !== after.bankAccountNumber ||
      before.ifscCode !== after.ifscCode;
    if (bankChanged && after.bankAccountNumber) {
      await logActivity({
        actorId: uid,
        action: "seller.bank_details_updated",
        targetType: "seller_application",
        targetId: uid,
        metadata: {},
      });
    }
  }
);

/* --------------------------------------------------------
   PRODUCTS — added / edited / deleted (seller). isActive-only
   flips (admin cascade deactivation, product-limit enforcement)
   are not "edits" the seller made, so they're excluded.
   -------------------------------------------------------- */

const PRODUCT_EDIT_FIELDS = ["name", "price", "quantity", "category", "mrp", "brand"];

const logProductChange = onDocumentWritten("products/{productId}", async (event) => {
  const before = event.data.before?.exists ? event.data.before.data() : null;
  const after = event.data.after?.exists ? event.data.after.data() : null;
  const productId = event.params.productId;

  if (!before && after) {
    await logActivity({
      actorId: after.sellerId,
      action: "product.added",
      targetType: "product",
      targetId: productId,
      metadata: { name: after.name || null },
    });
    return;
  }

  if (before && !after) {
    await logActivity({
      actorId: before.sellerId,
      action: "product.deleted",
      targetType: "product",
      targetId: productId,
      metadata: { name: before.name || null },
    });
    return;
  }

  if (before && after) {
    const changed = PRODUCT_EDIT_FIELDS.some((f) => before[f] !== after[f]);
    if (changed) {
      await logActivity({
        actorId: after.sellerId,
        action: "product.edited",
        targetType: "product",
        targetId: productId,
        metadata: { name: after.name || null },
      });
    }
  }
});

/* --------------------------------------------------------
   SHOPS — created (seller, at onboarding) and activated/
   deactivated (admin visibility toggle only - the OTHER way a
   shop's isActive flips, via successful plan payment, is logged
   inline in the razorpayWebhook handler in index.js instead,
   since that's already server-side with sellerId in hand).
   -------------------------------------------------------- */

const logShopCreated = onDocumentCreated("shops/{shopId}", async (event) => {
  const shop = event.data?.data();
  if (!shop) return;

  await logActivity({
    actorId: shop.sellerId,
    action: "shop.created",
    targetType: "shop",
    targetId: event.params.shopId,
    metadata: { shopName: shop.shopName || null },
  });
});

const logShopToggled = onDocumentUpdated("shops/{shopId}", async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  if (!before || !after) return;
  if (before.isActive === after.isActive) return;
  // Only the admin-toggle path sets this field (see toggleShopActive /
  // toggleShopWithProducts) - the webhook's own activation write doesn't,
  // so this won't double-log that case.
  if (!after.lastToggledBy) return;

  await logActivity({
    actorId: after.lastToggledBy,
    action: after.isActive ? "shop.activated" : "shop.deactivated",
    targetType: "shop",
    targetId: event.params.shopId,
    metadata: { shopName: after.shopName || null },
  });
});

/* --------------------------------------------------------
   SETTLEMENTS — admin records a seller payout as paid.
   -------------------------------------------------------- */

const logSettlementCreated = onDocumentCreated("settlements/{settlementId}", async (event) => {
  const settlement = event.data?.data();
  if (!settlement) return;

  await logActivity({
    actorId: settlement.settledBy,
    action: "settlement.marked_paid",
    targetType: "settlement",
    targetId: event.params.settlementId,
    metadata: {
      sellerId: settlement.sellerId || null,
      totalAmount: settlement.totalAmount ?? null,
      orderIds: settlement.orderIds || [],
    },
  });
});

/* --------------------------------------------------------
   PROFILE — buyer/seller changes their own delivery address
   (society/flat). Fires on first-time profile completion too.
   -------------------------------------------------------- */

const logProfileAddressChanged = onDocumentUpdated("users/{uid}", async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  const uid = event.params.uid;
  if (!before || !after) return;
  if (before.societyId === after.societyId && before.flatNumber === after.flatNumber) return;

  await logActivity({
    actorId: uid,
    action: "profile.address_changed",
    targetType: "user",
    targetId: uid,
    metadata: { societyId: after.societyId || null, flatNumber: after.flatNumber || null },
  });
});

module.exports = {
  logActivity,
  logOrderPlaced,
  logOrderStatusChange,
  logSellerApplicationSubmitted,
  logSellerApplicationDecision,
  logProductChange,
  logShopCreated,
  logShopToggled,
  logSettlementCreated,
  logProfileAddressChanged,
};

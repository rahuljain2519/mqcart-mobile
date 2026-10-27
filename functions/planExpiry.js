/* =========================================================
   ⏳ PLAN EXPIRY ENFORCEMENT
   Closes a real gap: expiresAt/autoRenew were written on every plan
   activation (free or paid) but nothing ever read them back - a seller
   who activated once stayed "active" forever regardless of plan validity.

   Runs daily (mirrors nightlyAggregation's onSchedule pattern) and, for
   every subscription past its validity:
     - Free plan: everyone shares one fixed calendar cutoff (31 Mar 2027),
       not N days from their own activation date - checked directly
       against that constant, ignoring whatever was stored in expiresAt
       (covers sellers who activated under the old per-seller logic too).
     - Paid plan: checked against expiresAt as already written by the
       activation webhook (30-day cycle, renewed by paying again - no
       auto-debit, see razorpayWebhook's reactivation branch below).

   Hides the shop's products rather than deleting anything: isActive is
   the same flag every buyer-facing query already filters on, so setting
   it false here is identical in effect to the admin's own
   toggleShopActive. hiddenByPlanExpiry marks which products were turned
   off *by this job* (as opposed to a seller's own manual "out of stock"
   toggle) so the webhook's reactivation branch only restores the ones
   this job hid, not everything indiscriminately.
   ========================================================= */

const admin = require("firebase-admin");
const { onSchedule } = require("firebase-functions/v2/scheduler");

// Fixed calendar date - deliberately not configurable via platform_config;
// this is a one-time business decision, not an ongoing plan parameter.
const FREE_PLAN_CUTOFF = new Date("2027-03-31T00:00:00+05:30");

async function hideShopProducts(db, shopId) {
  const productsSnap = await db
    .collection("products")
    .where("shopId", "==", shopId)
    .where("isActive", "==", true)
    .get();

  const docs = productsSnap.docs;
  for (let i = 0; i < docs.length; i += 400) {
    const batch = db.batch();
    docs.slice(i, i + 400).forEach((d) => {
      batch.update(d.ref, { isActive: false, hiddenByPlanExpiry: true });
    });
    await batch.commit();
  }
  return docs.length;
}

exports.enforcePlanExpiry = onSchedule(
  { schedule: "0 3 * * *", timeZone: "Asia/Kolkata" },
  async () => {
    const db = admin.firestore();
    const now = new Date();

    const activeSubsSnap = await db
      .collection("seller_subscriptions")
      .where("status", "==", "active")
      .get();

    for (const subDoc of activeSubsSnap.docs) {
      const sub = subDoc.data();
      const sellerId = subDoc.id;
      const { shopId, currentPlan, expiresAt } = sub;
      if (!shopId) continue;

      if (currentPlan === "free") {
        if (now < FREE_PLAN_CUTOFF) {
          // Not expired yet - opportunistically correct expiresAt for
          // display purposes on subscriptions activated before this fixed
          // cutoff existed (old per-seller validityDays logic).
          const stored = expiresAt?.toDate?.();
          if (!stored || stored.getTime() !== FREE_PLAN_CUTOFF.getTime()) {
            await subDoc.ref.update({
              expiresAt: admin.firestore.Timestamp.fromDate(FREE_PLAN_CUTOFF),
            });
          }
          continue;
        }
      } else {
        const expiryDate = expiresAt?.toDate?.();
        if (!expiryDate || expiryDate > now) continue;
      }

      console.log("PLAN EXPIRED", { sellerId, shopId, currentPlan });

      await subDoc.ref.update({
        status: "expired",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      await db.collection("shops").doc(shopId).update({
        isActive: false,
        planStatus: "expired",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      const hiddenCount = await hideShopProducts(db, shopId);
      console.log("PRODUCTS HIDDEN", { shopId, hiddenCount });

      await require("./activityLog").logActivity({
        actorId: sellerId,
        action: "seller.plan_expired",
        targetType: "shop",
        targetId: shopId,
        metadata: { plan: currentPlan },
      });
    }
  }
);

exports.FREE_PLAN_CUTOFF = FREE_PLAN_CUTOFF;

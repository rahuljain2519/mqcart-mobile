/* =========================================================
   💸 BUYER REFUNDS ON CANCEL/REJECT
   Closes a real gap: a buyer who paid online (razorpay) and then had
   their order cancelled (by themselves, while still "placed") or
   rejected (by the seller) had their money simply stay captured - no
   refund existed anywhere in this codebase before this file.

   Automatic, not admin-gated: in both cases the sale didn't happen, so
   there's no legitimate reason to hold the money pending a manual step.
   This mirrors the existing "webhook is the single source of truth"
   philosophy (see razorpayWebhook) - this trigger only *initiates* the
   refund and records Razorpay's immediate response; the webhook's
   refund.processed/refund.failed branch (index.js) is what confirms
   the final outcome, since a refund can take days to actually settle.
   ========================================================= */

const admin = require("firebase-admin");
const { onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { defineSecret } = require("firebase-functions/params");
const Razorpay = require("razorpay");

const RAZORPAY_KEY_ID = defineSecret("RAZORPAY_KEY_ID");
const RAZORPAY_KEY_SECRET = defineSecret("RAZORPAY_KEY_SECRET");

exports.refundCancelledOrRejectedOrder = onDocumentUpdated(
  { document: "orders/{orderId}", secrets: [RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET] },
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    const orderId = event.params.orderId;

    const justTransitioned =
      (after.status === "cancelled" || after.status === "rejected") &&
      before.status !== after.status;

    if (!justTransitioned) return;
    if (after.paymentMethod !== "razorpay" || after.paymentStatus !== "paid") return;

    if (!after.razorpayPaymentId) {
      // Orders placed before razorpayPaymentId was denormalized onto the
      // order itself have no way to look up the payment here - flag it
      // rather than silently doing nothing.
      console.warn("REFUND NEEDED BUT NO razorpayPaymentId ON ORDER", orderId);
      return;
    }

    const db = admin.firestore();

    // Guard against duplicate trigger delivery - re-check the live
    // document (not the possibly-stale `after` snapshot) before issuing a
    // second refund for the same order.
    const fresh = await db.collection("orders").doc(orderId).get();
    if (fresh.data()?.refundStatus) {
      console.log("REFUND ALREADY IN PROGRESS, SKIPPING", orderId);
      return;
    }

    const razorpay = new Razorpay({
      key_id: RAZORPAY_KEY_ID.value(),
      key_secret: RAZORPAY_KEY_SECRET.value(),
    });

    try {
      const refund = await razorpay.payments.refund(after.razorpayPaymentId, {
        amount: Math.round(after.totalAmount * 100),
      });

      const completed = refund.status === "processed";
      await db.collection("orders").doc(orderId).update({
        refundStatus: completed ? "completed" : "initiated",
        razorpayRefundId: refund.id,
        refundInitiatedAt: admin.firestore.FieldValue.serverTimestamp(),
        ...(completed ? { refundedAt: admin.firestore.FieldValue.serverTimestamp() } : {}),
      });

      await require("./activityLog").logActivity({
        actorId: after.buyerId,
        action: "order.refund_initiated",
        targetType: "order",
        targetId: orderId,
        metadata: { amount: after.totalAmount, reason: after.status },
      });

      console.log("REFUND INITIATED", { orderId, refundId: refund.id, status: refund.status });
    } catch (err) {
      console.error("REFUND FAILED TO INITIATE", orderId, err.message);
      await db.collection("orders").doc(orderId).update({
        refundStatus: "failed",
        refundFailureReason: err.message,
      });
    }
  }
);

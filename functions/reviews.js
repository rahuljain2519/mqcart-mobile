/* =========================================================
   ⭐ REVIEW AGGREGATES
   A buyer's review write (reviews/{orderId}_{productId}, see
   firestore.rules in mqcart-web for the write guard - only the delivered
   order's own buyer can create it, once) only contains the raw rating.
   This trigger keeps a running ratingSum/reviewCount on both the product
   and its shop so every product card / shop header can show an average
   without reading the whole reviews collection on every page load.

   FieldValue.increment is used rather than a transaction that reads-then-
   writes the average - simpler, and the rare double-increment on a Cloud
   Functions retry is an acceptable trade-off already made elsewhere in
   this codebase (nightlyAggregation, productCount) rather than new
   territory for this feature.
   ========================================================= */

const admin = require("firebase-admin");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");

const onReviewCreated = onDocumentCreated("reviews/{reviewId}", async (event) => {
  const review = event.data?.data();
  if (!review) return;

  const { productId, shopId, rating } = review;
  const inc = admin.firestore.FieldValue.increment(rating);
  const incOne = admin.firestore.FieldValue.increment(1);

  const writes = [];
  if (productId) {
    writes.push(
      admin.firestore().collection("products").doc(productId).update({
        ratingSum: inc,
        reviewCount: incOne,
      }).catch(() => {})
    );
  }
  if (shopId) {
    writes.push(
      admin.firestore().collection("shops").doc(shopId).update({
        ratingSum: inc,
        reviewCount: incOne,
      }).catch(() => {})
    );
  }
  await Promise.all(writes);
});

module.exports = { onReviewCreated };

import 'package:flutter/material.dart';

import '../../models/product_model.dart';
import '../../models/review_model.dart';
import '../../repositories/review_repository.dart';
import 'star_rating.dart';

String _timeAgo(DateTime? d) {
  if (d == null) return '';
  final days = DateTime.now().difference(d).inDays;
  if (days <= 0) return 'today';
  if (days == 1) return '1 day ago';
  if (days < 30) return '$days days ago';
  return '${d.day}/${d.month}/${d.year}';
}

class ProductReviews extends StatefulWidget {
  final ProductModel product;

  const ProductReviews({super.key, required this.product});

  @override
  State<ProductReviews> createState() => _ProductReviewsState();
}

class _ProductReviewsState extends State<ProductReviews> {
  final _reviewRepository = ReviewRepository();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ReviewModel>>(
      stream: _reviewRepository.streamReviewsForProduct(widget.product.id),
      builder: (context, snapshot) {
        final reviews = snapshot.data ?? const <ReviewModel>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Ratings & reviews',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                RatingSummary(
                  ratingSum: widget.product.ratingSum,
                  reviewCount: widget.product.reviewCount,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (reviews.isEmpty)
              const Text('No reviews yet.', style: TextStyle(color: Colors.black54))
            else
              ...reviews.map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            StarDisplay(rating: r.rating.toDouble()),
                            const SizedBox(width: 6),
                            Text(r.buyerName,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            const SizedBox(width: 6),
                            Text(_timeAgo(r.createdAt),
                                style: const TextStyle(fontSize: 11, color: Colors.black45)),
                          ],
                        ),
                        if (r.comment != null && r.comment!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(r.comment!, style: const TextStyle(fontSize: 13)),
                          ),
                      ],
                    ),
                  )),
          ],
        );
      },
    );
  }
}

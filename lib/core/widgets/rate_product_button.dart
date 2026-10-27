import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/order_model.dart';
import '../../repositories/product_repository.dart';
import '../../repositories/review_repository.dart';
import '../../repositories/user_repository.dart';
import 'star_rating.dart';

/// Inline "Rate" control for one delivered order item - checks once on
/// mount whether this order+product already has a review (so a screen
/// re-render doesn't offer to rate twice), then opens a small star+comment
/// dialog on tap.
class RateProductButton extends StatefulWidget {
  final OrderModel order;
  final Map<String, dynamic> item;

  const RateProductButton({super.key, required this.order, required this.item});

  @override
  State<RateProductButton> createState() => _RateProductButtonState();
}

class _RateProductButtonState extends State<RateProductButton> {
  final _reviewRepository = ReviewRepository();
  bool? _rated; // null = checking

  @override
  void initState() {
    super.initState();
    final productId = widget.item['productId'] as String?;
    if (productId == null) {
      setState(() => _rated = true); // nothing sensible to rate
      return;
    }
    _reviewRepository.getReview(widget.order.id, productId).then((r) {
      if (mounted) setState(() => _rated = r != null);
    });
  }

  Future<void> _openDialog() async {
    final productId = widget.item['productId'] as String?;
    if (productId == null) return;

    int rating = 0;
    String comment = '';
    String? error;
    bool submitting = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text('Rate ${widget.item['name'] ?? 'this product'}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StarInput(value: rating, onChanged: (v) => setDialogState(() => rating = v)),
                const SizedBox(height: 8),
                TextField(
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Share your experience (optional)',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => comment = v,
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: submitting
                    ? null
                    : () async {
                        if (rating == 0) {
                          setDialogState(() => error = 'Pick a star rating first.');
                          return;
                        }
                        setDialogState(() {
                          submitting = true;
                          error = null;
                        });
                        try {
                          final buyerId = FirebaseAuth.instance.currentUser!.uid;
                          final buyer = await UserRepository().getUser(buyerId);
                          final product = await ProductRepository().getProductById(productId);
                          if (product == null) {
                            throw Exception('This product no longer exists.');
                          }
                          await _reviewRepository.submitReview(
                            orderId: widget.order.id,
                            productId: productId,
                            shopId: product.shopId,
                            sellerId: widget.order.sellerId,
                            buyerId: buyerId,
                            buyerName: buyer.name.isNotEmpty ? buyer.name : 'Buyer',
                            rating: rating,
                            comment: comment.trim().isEmpty ? null : comment.trim(),
                          );
                          if (ctx.mounted) Navigator.of(ctx).pop();
                          if (mounted) setState(() => _rated = true);
                        } catch (e) {
                          setDialogState(() {
                            submitting = false;
                            error = 'Could not submit review.';
                          });
                        }
                      },
                child: Text(submitting ? 'Submitting…' : 'Submit'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_rated == null) return const SizedBox.shrink();
    if (_rated == true) {
      return const Text('Rated', style: TextStyle(fontSize: 11, color: Colors.grey));
    }
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: _openDialog,
      child: const Text('Rate', style: TextStyle(fontSize: 11)),
    );
  }
}

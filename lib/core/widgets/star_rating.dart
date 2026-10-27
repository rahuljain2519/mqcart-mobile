import 'package:flutter/material.dart';

const _mqOrange = Color(0xFFFF6A00);

/// Read-only stars - `rating` can be fractional (an average), filled
/// proportionally per-star rather than rounded to the nearest whole star.
class StarDisplay extends StatelessWidget {
  final double rating;
  final double size;

  const StarDisplay({super.key, required this.rating, this.size = 14});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final fill = (rating - i).clamp(0.0, 1.0);
        return Stack(
          children: [
            Icon(Icons.star, size: size, color: Colors.grey.shade300),
            ClipRect(
              clipper: _FractionClipper(fill),
              child: Icon(Icons.star, size: size, color: _mqOrange),
            ),
          ],
        );
      }),
    );
  }
}

class _FractionClipper extends CustomClipper<Rect> {
  final double fraction;
  _FractionClipper(this.fraction);

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, size.width * fraction, size.height);

  @override
  bool shouldReclip(covariant CustomClipper<Rect> oldClipper) =>
      oldClipper is _FractionClipper && oldClipper.fraction != fraction;
}

/// Tappable 1-5 star picker for writing a review.
class StarInput extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final double size;

  const StarInput({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final star = i + 1;
        return IconButton(
          padding: const EdgeInsets.all(2),
          constraints: const BoxConstraints(),
          icon: Icon(
            star <= value ? Icons.star : Icons.star_border,
            size: size,
            color: _mqOrange,
          ),
          onPressed: () => onChanged(star),
        );
      }),
    );
  }
}

/// Compact "★ 4.5 (12)" summary used on cards/headers. Renders nothing
/// when there's nothing to show yet (no reviews).
class RatingSummary extends StatelessWidget {
  final int? ratingSum;
  final int? reviewCount;
  final double size;

  const RatingSummary({
    super.key,
    required this.ratingSum,
    required this.reviewCount,
    this.size = 14,
  });

  @override
  Widget build(BuildContext context) {
    if (reviewCount == null || reviewCount == 0) return const SizedBox.shrink();
    final avg = ratingSum! / reviewCount!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        StarDisplay(rating: avg, size: size),
        const SizedBox(width: 4),
        Text(
          '${avg.toStringAsFixed(1)} ($reviewCount)',
          style: TextStyle(fontSize: size - 1, color: Colors.black54),
        ),
      ],
    );
  }
}

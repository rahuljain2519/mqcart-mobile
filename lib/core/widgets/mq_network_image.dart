import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class MQNetworkImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const MQNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return _placeholder();
    }

    Widget image = CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      // Cap decode width only — height stays proportional so banners and
      // full-width images keep their aspect ratio.
      memCacheWidth: 800,
      fadeInDuration: const Duration(milliseconds: 100),
      placeholder: (_, _) => _placeholder(),
      errorWidget: (_, _, _) => const Icon(Icons.image_not_supported),
    );

    if (borderRadius != null) {
      image = ClipRRect(
        borderRadius: borderRadius!,
        child: image,
      );
    }

    return image;
  }

  Widget _placeholder() {
    return Container(
      width: width,
      height: height,
      color: Colors.grey.shade200,
      alignment: Alignment.center,
      child: const Icon(Icons.image, size: 32, color: Colors.grey),
    );
  }
}

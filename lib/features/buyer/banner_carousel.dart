import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/widgets/mq_network_image.dart';
import '../../repositories/banner_repository.dart';

const _slideDuration = Duration(milliseconds: 4500);
const _transitionDuration = Duration(milliseconds: 450);

/// Auto-sliding carousel of admin-managed landing page banners, same
/// `banners` collection and active/order fields as the web admin's
/// Banners page. Renders nothing while loading or when there are none.
class BannerCarousel extends StatefulWidget {
  const BannerCarousel({super.key});

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  final BannerRepository _repo = BannerRepository();
  final PageController _controller = PageController();
  Timer? _timer;
  int _index = 0;
  List<BannerModel>? _banners;

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _restartTimer(int count) {
    _timer?.cancel();
    if (count < 2) return;
    _timer = Timer.periodic(_slideDuration, (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_index + 1) % count;
      _controller.animateToPage(
        next,
        duration: _transitionDuration,
        curve: Curves.easeInOut,
      );
    });
  }

  Future<void> _openLink(String? linkUrl) async {
    if (linkUrl == null || linkUrl.isEmpty) return;
    final uri = Uri.tryParse(linkUrl);
    if (uri == null || !uri.hasScheme) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BannerModel>>(
      stream: _repo.streamActiveBanners(),
      builder: (context, snapshot) {
        final banners = snapshot.data;
        if (banners == null || banners.isEmpty) return const SizedBox.shrink();

        if (_banners?.length != banners.length) {
          _banners = banners;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _restartTimer(banners.length);
          });
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 140,
              child: Stack(
                children: [
                  PageView.builder(
                    controller: _controller,
                    itemCount: banners.length,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (context, i) {
                      final b = banners[i];
                      return GestureDetector(
                        onTap: () => _openLink(b.linkUrl),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Blurred, scaled-up copy fills the frame behind
                            // images that don't match this box's aspect
                            // ratio, instead of leaving bare white space
                            // either side of a letterboxed contain image.
                            ClipRect(
                              child: ImageFiltered(
                                imageFilter:
                                    ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                                child: Transform.scale(
                                  scale: 1.2,
                                  child: MQNetworkImage(
                                    url: b.imageUrl,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                  ),
                                ),
                              ),
                            ),
                            Container(color: Colors.black.withOpacity(0.1)),
                            MQNetworkImage(
                              url: b.imageUrl,
                              fit: BoxFit.contain,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  if (banners.length > 1)
                    Positioned(
                      bottom: 8,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(banners.length, (i) {
                          final active = i == _index;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            width: active ? 16 : 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(active ? 1 : 0.6),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          );
                        }),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

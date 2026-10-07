import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';

import '../core/providers/subscription_provider.dart';
import '../platform/ad_service.dart';

const double kAdBannerSlotHeight = 60.0;

/// Fixed-height banner. Collapses to 0dp while loading, on failure, and
/// when ad-free — never a broken placeholder.
///
/// Every slot owns its OWN BannerAd (created on mount, disposed on
/// unmount). A single shared ad cannot be shown in two places at once, and
/// one screen closing used to destroy the ad another screen was showing.
///
/// SubscriptionProvider is located via Provider.of(context, listen: false)
/// — DI only, per the architecture rule; reactivity comes from the
/// ValueListenableBuilder below.
class AdBannerSlot extends StatefulWidget {
  const AdBannerSlot({super.key, required this.personalized});

  final bool personalized;

  @override
  State<AdBannerSlot> createState() => _AdBannerSlotState();
}

class _AdBannerSlotState extends State<AdBannerSlot> {
  late final SubscriptionProvider _subscriptionProvider;
  BannerAd? _banner;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _subscriptionProvider =
        Provider.of<SubscriptionProvider>(context, listen: false);
    _load();
  }

  Future<void> _load() async {
    if (_subscriptionProvider.value) return; // ad-free, nothing to load
    final banner = await AdService.instance.loadBannerAd(
      personalized: widget.personalized,
      onLoaded: (_) {
        if (mounted) setState(() => _loaded = true);
      },
      onFailed: (_, __) {
        if (mounted) {
          setState(() {
            _loaded = false;
            _banner = null;
          });
        }
      },
    );
    if (!mounted) {
      banner?.dispose();
      return;
    }
    if (banner != null) setState(() => _banner = banner);
  }

  @override
  void dispose() {
    _banner?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _subscriptionProvider,
      builder: (context, isAdFree, _) {
        final banner = _banner;
        if (isAdFree || banner == null || !_loaded) {
          return const SizedBox.shrink();
        }
        return SizedBox(
          height: kAdBannerSlotHeight,
          width: double.infinity,
          child: AdWidget(ad: banner),
        );
      },
    );
  }
}

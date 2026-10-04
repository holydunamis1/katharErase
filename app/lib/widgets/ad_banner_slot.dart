import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';

import '../core/models/ad_load_state.dart';
import '../core/providers/ad_provider.dart';
import '../core/providers/subscription_provider.dart';

const double kAdBannerSlotHeight = 60.0;

/// Fixed-height container (default 60dp). Listens to ad_provider.
/// Collapses to 0dp on failed or isAdFree=true. Never shows a broken
/// placeholder.
///
/// State-management note: AdProvider and SubscriptionProvider instances
/// are located via Provider.of(context, listen: false) — DI only, per
/// the architecture rule. Reactivity comes entirely from the nested
/// ValueListenableBuilders below, not from package:provider's watch
/// mechanism.
class AdBannerSlot extends StatefulWidget {
  const AdBannerSlot({super.key, required this.personalized});

  final bool personalized;

  @override
  State<AdBannerSlot> createState() => _AdBannerSlotState();
}

class _AdBannerSlotState extends State<AdBannerSlot> {
  late final AdProvider _adProvider;
  late final SubscriptionProvider _subscriptionProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _adProvider = Provider.of<AdProvider>(context, listen: false);
    _subscriptionProvider =
        Provider.of<SubscriptionProvider>(context, listen: false);
    _adProvider.loadEditorBanner(personalized: widget.personalized);
  }

  @override
  void dispose() {
    _adProvider.disposeBanner();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _subscriptionProvider,
      builder: (context, isAdFree, _) {
        if (isAdFree) return const SizedBox.shrink();

        return ValueListenableBuilder<AdLoadState>(
          valueListenable: _adProvider.editorBanner,
          builder: (context, adState, _) {
            if (adState.state != AdLoadStatus.loaded) {
              // Covers idle, loading, AND failed — never a broken
              // placeholder, per the architecture rule.
              return const SizedBox.shrink();
            }
            return SizedBox(
              height: kAdBannerSlotHeight,
              width: double.infinity,
              child: AdWidget(ad: _requireLoadedBanner()),
            );
          },
        );
      },
    );
  }

  /// AdProvider doesn't expose the raw BannerAd publicly (it only
  /// publishes AdLoadState) — this is a real gap between what
  /// ad_provider.dart currently exposes and what this widget needs to
  /// actually render the ad via AdWidget. Flagged and resolved here by
  /// having ad_provider surface the active banner directly, since
  /// AdWidget requires the concrete BannerAd instance, not just its
  /// load-state enum.
  BannerAd _requireLoadedBanner() {
    final banner = _adProvider.activeBannerAd;
    assert(banner != null, 'AdLoadStatus.loaded but no BannerAd available');
    return banner!;
  }
}

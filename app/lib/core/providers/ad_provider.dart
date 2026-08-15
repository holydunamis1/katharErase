import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../platform/ad_service.dart';
import '../models/ad_load_state.dart';
import 'subscription_provider.dart';

const String kPlacementEditorBanner = 'editor_banner';
const String kPlacementPostExportInterstitial = 'post_export_interstitial';

/// `ValueNotifier<AdLoadState>` per placement, per Section 4. Only two
/// placements exist in this app (editor_banner, post_export_interstitial)
/// so this is two named, individually-listenable ValueNotifier fields
/// rather than a dynamic `Map<String, AdLoadState>` — simpler and
/// type-safe for a fixed, known set of placements, while still matching
/// "ValueNotifier per placement" literally.
class AdProvider {
  AdProvider(this._subscriptionProvider);

  final SubscriptionProvider _subscriptionProvider;

  final ValueNotifier<AdLoadState> editorBanner = ValueNotifier(
    const AdLoadState(placementId: kPlacementEditorBanner),
  );

  final ValueNotifier<AdLoadState> postExportInterstitial = ValueNotifier(
    const AdLoadState(placementId: kPlacementPostExportInterstitial),
  );

  BannerAd? _activeBanner;

  /// Publicly exposed so ad_banner_slot.dart (Phase 4) can pass the
  /// concrete BannerAd to google_mobile_ads' AdWidget, which requires the
  /// actual ad instance — AdLoadState's enum alone isn't enough to render
  /// anything, only to decide whether rendering should be attempted.
  BannerAd? get activeBannerAd => _activeBanner;

  /// ad_banner_slot.dart (Phase 4) calls this on mount. Does nothing if
  /// isAdFree — the widget itself should also check isAdFree before
  /// calling this, but this is a second line of defense per the
  /// architecture rule that ad slots collapse to 0dp and never show a
  /// broken placeholder.
  Future<void> loadEditorBanner({required bool personalized}) async {
    if (_subscriptionProvider.value) return; // ad-free, nothing to load

    editorBanner.value = editorBanner.value.copyWith(
      state: AdLoadStatus.loading,
    );

    final banner = await AdService.instance.loadBannerAd(
      personalized: personalized,
      onLoaded: (_) {
        editorBanner.value = editorBanner.value.copyWith(
          state: AdLoadStatus.loaded,
        );
      },
      onFailed: (_, error) {
        editorBanner.value = editorBanner.value.copyWith(
          state: AdLoadStatus.failed,
          errorMessage: error.message,
        );
      },
    );
    _activeBanner = banner;
  }

  /// export_bottom_sheet.dart (Phase 5) calls this after a successful
  /// export. AdService itself enforces the 120s capping interval, so this
  /// method doesn't need to duplicate that check — it just reflects
  /// whatever AdService actually did into AdLoadState for the UI.
  Future<void> maybeShowPostExportInterstitial({
    required bool personalized,
  }) async {
    if (_subscriptionProvider.value) return; // ad-free

    postExportInterstitial.value = postExportInterstitial.value.copyWith(
      state: AdLoadStatus.loading,
    );
    final shown = await AdService.instance.maybeLoadAndShowInterstitial(
      personalized: personalized,
    );
    postExportInterstitial.value = postExportInterstitial.value.copyWith(
      state: shown ? AdLoadStatus.loaded : AdLoadStatus.failed,
    );
  }

  void disposeBanner() {
    _activeBanner?.dispose();
    _activeBanner = null;
  }

  void dispose() {
    disposeBanner();
    editorBanner.dispose();
    postExportInterstitial.dispose();
  }
}

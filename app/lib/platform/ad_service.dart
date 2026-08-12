import 'dart:async';
import 'dart:io' show Platform;

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../core/utils/constants.dart';

/// AdMob init, ATT request, banner/interstitial load-show, capping logic.
/// This is where OS-branching logic lives per A3 (Section 11) — the
/// dart:io Platform.isIOS check and kReleaseMode branching are the actual
/// substance of the core/ vs platform/ split, unlike the plugin-import
/// question resolved for core/services/ files.
///
/// google_mobile_ads v9 API notes (live-verified before writing this
/// file): "unitId" was renamed to "adUnitId" in BannerAd/InterstitialAd
/// constructors; BannerAd requires an explicit AdSize (smart banner is
/// deprecated); interstitials use static InterstitialAd.load() with an
/// InterstitialAdLoadCallback, not the old delegate pattern.
class AdService {
  AdService._();
  static final AdService instance = AdService._();

  DateTime? _lastInterstitialShownAt;

  String get bannerAdUnitId => kReleaseMode
      ? (Platform.isIOS ? kProdBannerAdUnitIdIos : kProdBannerAdUnitIdAndroid)
      : (Platform.isIOS ? kTestBannerAdUnitIdIos : kTestBannerAdUnitIdAndroid);

  String get interstitialAdUnitId => kReleaseMode
      ? (Platform.isIOS
          ? kProdInterstitialAdUnitIdIos
          : kProdInterstitialAdUnitIdAndroid)
      : (Platform.isIOS
          ? kTestInterstitialAdUnitIdIos
          : kTestInterstitialAdUnitIdAndroid);

  Future<void> initialize() async {
    try {
      await MobileAds.instance.initialize();
    } catch (e) {
      // Ad SDK failing to init should never block the app — the feature
      // set is fully free/unlocked regardless of ad state per
      // subscription_provider's rule ("no feature gates, no export
      // blocked").
      // ignore: avoid_print
      print('AdMob initialization failed: $e');
    }
  }

  /// Request ATT authorization (iOS only). Returns whether personalized
  /// ads are permitted; caller (settings_provider / ad_provider, Phase 3)
  /// should request a non-personalized AdRequest when this is false.
  Future<bool> requestTrackingAuthorization() async {
    if (!Platform.isIOS) return true; // Android: AD_ID handles this path.
    try {
      final status =
          await AppTrackingTransparency.requestTrackingAuthorization();
      return status == TrackingStatus.authorized;
    } catch (e) {
      // ignore: avoid_print
      print('ATT request failed: $e');
      return false; // fail safe -> non-personalized
    }
  }

  AdRequest _buildAdRequest({required bool personalized}) {
    return AdRequest(nonPersonalizedAds: !personalized);
  }

  /// Loads a banner ad for ad_banner_slot.dart (Phase 4). Caller owns
  /// disposal via the returned BannerAd's .dispose(). Returns null on
  /// failure — the widget collapses to 0dp per the architecture rule,
  /// never showing a broken placeholder.
  Future<BannerAd?> loadBannerAd({
    required bool personalized,
    required void Function(Ad ad) onLoaded,
    required void Function(Ad ad, LoadAdError error) onFailed,
  }) async {
    final banner = BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: _buildAdRequest(personalized: personalized),
      listener: BannerAdListener(
        onAdLoaded: onLoaded,
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          onFailed(ad, error);
        },
      ),
    );
    try {
      await banner.load();
      return banner;
    } catch (e) {
      // ignore: avoid_print
      print('Banner ad load failed: $e');
      return null;
    }
  }

  /// Loads an interstitial for post-export display (export_bottom_sheet,
  /// Phase 5). Respects the 120s capping interval per Section 9 — returns
  /// false immediately without attempting a load if still within the
  /// cooldown, so callers don't need to duplicate the timing check.
  /// Returns true only if an ad was actually shown.
  Future<bool> maybeLoadAndShowInterstitial({
    required bool personalized,
  }) async {
    final last = _lastInterstitialShownAt;
    if (last != null) {
      final elapsed = DateTime.now().difference(last).inSeconds;
      if (elapsed < kInterstitialMinIntervalSeconds) return false;
    }

    final completer = Completer<bool>();
    try {
      await InterstitialAd.load(
        adUnitId: interstitialAdUnitId,
        request: _buildAdRequest(personalized: personalized),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (dismissedAd) {
                dismissedAd.dispose();
              },
              onAdFailedToShowFullScreenContent: (failedAd, error) {
                failedAd.dispose();
              },
            );
            ad.show();
            _lastInterstitialShownAt = DateTime.now();
            if (!completer.isCompleted) completer.complete(true);
          },
          onAdFailedToLoad: (error) {
            // ignore: avoid_print
            print('Interstitial load failed: $error');
            if (!completer.isCompleted) completer.complete(false);
          },
        ),
      );
    } catch (e) {
      // ignore: avoid_print
      print('Interstitial load threw: $e');
      if (!completer.isCompleted) completer.complete(false);
    }
    return completer.future;
  }
}

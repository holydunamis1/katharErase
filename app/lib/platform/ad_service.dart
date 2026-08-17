import 'dart:async';
import 'dart:io' show Platform;

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../core/utils/constants.dart';

class AdService {
  AdService._();
  static final AdService instance = AdService._();

  DateTime? _lastInterstitialShownAt;

  /// Returns the appropriate banner ad unit ID.
  /// Falls back to test IDs if production IDs still contain bracket
  /// placeholders (Section 1a pending items).
  String get bannerAdUnitId {
    final isIos = Platform.isIOS;
    final prodId = isIos ? kProdBannerAdUnitIdIos : kProdBannerAdUnitIdAndroid;
    final testId = isIos ? kTestBannerAdUnitIdIos : kTestBannerAdUnitIdAndroid;
    // Use production ID only in release mode AND only if it's a real ID
    // (no bracket placeholders). Otherwise fall back to test IDs to
    // prevent AdMob SDK crash on invalid ad unit format.
    return (kReleaseMode && !prodId.contains('[')) ? prodId : testId;
  }

  /// Returns the appropriate interstitial ad unit ID.
  /// Same fallback logic as bannerAdUnitId.
  String get interstitialAdUnitId {
    final isIos = Platform.isIOS;
    final prodId = isIos ? kProdInterstitialAdUnitIdIos : kProdInterstitialAdUnitIdAndroid;
    final testId = isIos ? kTestInterstitialAdUnitIdIos : kTestInterstitialAdUnitIdAndroid;
    return (kReleaseMode && !prodId.contains('[')) ? prodId : testId;
  }

  Future<void> initialize() async {
    try {
      await MobileAds.instance.initialize();
    } catch (e) {
      print('AdMob initialization failed: $e');
    }
  }

  Future<bool> requestTrackingAuthorization() async {
    if (!Platform.isIOS) return true;
    try {
      final status = await AppTrackingTransparency.requestTrackingAuthorization();
      return status == TrackingStatus.authorized;
    } catch (e) {
      print('ATT request failed: $e');
      return false;
    }
  }

  AdRequest _buildAdRequest({required bool personalized}) {
    return AdRequest(nonPersonalizedAds: !personalized);
  }

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
      print('Banner ad load failed: $e');
      // Notify caller of failure so widget doesn't hang
      onFailed(banner, LoadAdError(0, 'internal', 'load threw: $e', null));
      return null;
    }
  }

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
            print('Interstitial load failed: $error');
            if (!completer.isCompleted) completer.complete(false);
          },
        ),
      );
    } catch (e) {
      print('Interstitial load threw: $e');
      if (!completer.isCompleted) completer.complete(false);
    }
    return completer.future;
  }
}

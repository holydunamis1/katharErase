import 'package:flutter/foundation.dart';

import '../../platform/iap_service.dart';
import 'settings_provider.dart';

/// ValueNotifier<bool isAdFree>. Queries IAP on app start, listens to the
/// purchase stream.
///
/// Its only UI effect, per Section 4's explicit rule, is
/// `bool showAds = !isAdFree` — no feature gates, no buttons disabled, no
/// export blocked. Never wire this provider's value into anything else.
///
/// Caching note (Gap 6 resolution): the persisted UserSettings.isAdFree
/// field (owned by settings_provider) is read at init for an immediate,
/// non-flashing initial value — before the live IAP query resolves over
/// the network — then reconciled once the real entitlement check
/// completes. This directly serves Section 15's "app functions
/// identically when offline" check: a paying user shouldn't see ads for
/// the few seconds it takes IAP to respond, or at all if genuinely
/// offline.
class SubscriptionProvider extends ValueNotifier<bool> {
  SubscriptionProvider(this._settingsProvider) : super(false);

  final SettingsProvider _settingsProvider;

  /// Call once at app start (main.dart, Phase 6), after settings_provider
  /// has loaded, so the cached value is available immediately.
  void initialize() {
    value = _settingsProvider.value.isAdFree; // cached, non-authoritative seed

    IapService.instance.startListening(
      onEntitlementChanged: (isAdFree) {
        value = isAdFree;
        _settingsProvider.syncAdFreeStatus(isAdFree);
      },
      onError: (error) {
        // ignore: avoid_print
        print('IAP stream error: $error');
        // Deliberately do not flip `value` on error — keep showing
        // whatever the last-known-good entitlement state was (cached or
        // previously confirmed) rather than punishing a paying user with
        // ads because of a transient network/store issue.
      },
    );

    IapService.instance.restorePurchases().catchError((Object e) {
      // ignore: avoid_print
      print('Restore purchases on init failed: $e');
    });
  }

  @override
  void dispose() {
    IapService.instance.dispose();
    super.dispose();
  }
}

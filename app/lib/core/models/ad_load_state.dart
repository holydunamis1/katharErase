import 'package:freezed_annotation/freezed_annotation.dart';

part 'ad_load_state.freezed.dart';

enum AdLoadStatus { idle, loading, loaded, failed }

/// Runtime-only, per-placement state — not persisted. ad_provider.dart
/// (Phase 3) will hold one of these per placement id ('editor_banner',
/// 'post_export_interstitial' per Section 4).
///
/// Architecture rule: ad_banner_slot.dart (Phase 4) collapses to 0dp on
/// AdLoadStatus.failed or when isAdFree=true — never shows a broken
/// placeholder. This model carries the signal that widget reads.
///
/// freezed ^3.2.5 syntax: `abstract class`, not plain `class` (breaking
/// change from freezed 2.x — see pubspec.yaml comment on the freezed pin).
@freezed
abstract class AdLoadState with _$AdLoadState {
  const factory AdLoadState({
    required String placementId,
    @Default(AdLoadStatus.idle) AdLoadStatus state,
    String? errorMessage,
  }) = _AdLoadState;
}

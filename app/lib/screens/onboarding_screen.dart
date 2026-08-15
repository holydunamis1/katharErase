import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/providers/settings_provider.dart';
import '../core/utils/constants.dart';
import '../generated/l10n/app_localizations.dart';
import '../platform/ad_service.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/primary_button.dart';

/// 3 pages: Auto-remove demo, Manual brush demo, "Free with ads — go
/// ad-free for $0.99" explanation. "Get Started" button.
///
/// Asset note: assets/images/onboarding_*.png are Phase 9 files (74-76),
/// not yet placed on disk at the time this screen is written. Image.asset
/// calls below use errorBuilder fallbacks so this screen doesn't crash
/// before those assets exist — once Phase 9 places the real files, the
/// fallback path simply stops triggering.
///
/// Retrofit note: page title/body strings now come from AppLocalizations
/// rather than a static const list — AppLocalizations lookups are runtime
/// instance method calls, not compile-time constants, so _pages moved
/// from a static const field to a build-time method taking BuildContext.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _page = 0;

  static const _assets = [
    'assets/images/onboarding_auto.png',
    'assets/images/onboarding_manual.png',
    'assets/images/onboarding_ads.png',
  ];

  List<_OnboardingPageData> _pages(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return [
      _OnboardingPageData(
        asset: _assets[0],
        title: l10n.onboardingPage1Title,
        body: l10n.onboardingPage1Body,
      ),
      _OnboardingPageData(
        asset: _assets[1],
        title: l10n.onboardingPage2Title,
        body: l10n.onboardingPage2Body,
      ),
      _OnboardingPageData(
        asset: _assets[2],
        title: l10n.onboardingPage3Title,
        body: l10n.onboardingPage3Body,
      ),
    ];
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish(BuildContext context) async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    await settings.completeOnboarding();

    // ATT request (post-onboarding), Section 1a compliance table. This
    // is the immediate first-run trigger — main.dart's startup sequence
    // separately covers the returning-user case (onboarding completed in
    // a prior session but the app was killed before ATT could show).
    // AppTrackingTransparency's request call is safe to invoke more than
    // once — it only shows UI when status is notDetermined, otherwise it
    // just returns the existing status — so there's no double-prompt risk
    // between these two trigger points.
    if (!settings.value.hasSeenAttPrompt) {
      await AdService.instance.requestTrackingAuthorization();
      await settings.markAttPromptSeen();
    }

    if (context.mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accent =
        Theme.of(context).brightness == Brightness.dark
            ? AppColors.accentDark
            : AppColors.accentLight;
    final pages = _pages(context);

    return AppScaffold(
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: pages.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, i) => _OnboardingPage(data: pages[i]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(pages.length, (i) {
                    final active = i == _page;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: active ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: active ? accent : accent.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: _page == pages.length - 1
                      ? l10n.onboardingGetStarted
                      : l10n.onboardingNext,
                  onPressed: () {
                    if (_page == pages.length - 1) {
                      _finish(context);
                    } else {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPageData {
  const _OnboardingPageData({
    required this.asset,
    required this.title,
    required this.body,
  });
  final String asset;
  final String title;
  final String body;
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.data});
  final _OnboardingPageData data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Image.asset(
              data.asset,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.image_outlined,
                size: 96,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            data.title,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            data.body,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/providers/settings_provider.dart';
import '../core/utils/constants.dart';
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
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _page = 0;

  static const _pages = [
    _OnboardingPageData(
      asset: 'assets/images/onboarding_auto.png',
      title: 'Remove backgrounds instantly',
      body: 'Tap once and our on-device AI removes the background from '
          'your photo — no internet required.',
    ),
    _OnboardingPageData(
      asset: 'assets/images/onboarding_manual.png',
      title: 'Fine-tune with the brush',
      body: 'Zoom in and paint away anything the AI missed, or restore '
          'parts you want to keep.',
    ),
    _OnboardingPageData(
      asset: 'assets/images/onboarding_ads.png',
      title: 'Free with ads',
      body: 'Every feature is free, supported by ads. Go ad-free anytime '
          'for just \$0.99/month.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish(BuildContext context) async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    await settings.completeOnboarding();
    if (context.mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final accent =
        Theme.of(context).brightness == Brightness.dark
            ? AppColors.accentDark
            : AppColors.accentLight;

    return AppScaffold(
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _pages.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, i) => _OnboardingPage(data: _pages[i]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_pages.length, (i) {
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
                  label: _page == _pages.length - 1 ? 'Get Started' : 'Next',
                  onPressed: () {
                    if (_page == _pages.length - 1) {
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

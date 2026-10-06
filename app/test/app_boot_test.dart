import 'package:flutter_test/flutter_test.dart';
import 'package:katharerase/app.dart';
import 'package:katharerase/core/providers/ad_provider.dart';
import 'package:katharerase/core/providers/image_edit_provider.dart';
import 'package:katharerase/core/providers/settings_provider.dart';
import 'package:katharerase/core/providers/subscription_provider.dart';
import 'package:katharerase/core/providers/theme_provider.dart';
import 'package:katharerase/screens/onboarding_screen.dart';

/// Boots the REAL app widget tree (real router, real providers, real
/// localization) the way main() does, in debug mode where framework
/// assertions are active. A throw on the first build — like the
/// "Tried to use Provider with a subtype of Listenable" crash that left
/// debug builds frozen on the splash screen — fails this test, with no
/// APK or device needed.
KatharEraseApp _buildApp(SettingsProvider settings) {
  final subscription = SubscriptionProvider(settings);
  return KatharEraseApp(
    themeProvider: ThemeProvider(),
    settingsProvider: settings,
    subscriptionProvider: subscription,
    adProvider: AdProvider(subscription),
    imageEditProvider: ImageEditProvider(),
  );
}

void main() {
  testWidgets('fresh install: first screen (onboarding) builds without errors',
      (tester) async {
    await tester.pumpWidget(_buildApp(SettingsProvider()));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
    expect(find.byType(OnboardingScreen), findsOneWidget);
  });
}

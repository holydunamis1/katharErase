import Flutter
import UIKit
import GoogleMobileAds

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // AdMob SDK init. ATT request is deferred to ad_service.dart
    // (requestTrackingAuthorization, Phase 2) — triggered at the moment
    // onboarding completes (onboarding_screen.dart) or, for returning
    // users, during main.dart's startup sequence. Not requested here,
    // since native AppDelegate code runs before Dart/Flutter's onboarding
    // state is available to check.
    GADMobileAds.sharedInstance().start(completionHandler: nil)

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

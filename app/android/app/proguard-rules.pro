# ============================================================
# PROGUARD / R8 KEEP RULES
# minifyEnabled + shrinkResources are on for release builds
# (android/app/build.gradle, File 54).
# ============================================================

# --- google_mobile_ads (Section 5, File 55 original requirement) ---
-keep class com.google.android.gms.ads.** { *; }
-keep public class com.google.android.gms.ads.mediation.** { *; }
-keep public class com.google.ads.** { *; }

# --- in_app_purchase (Section 5, File 55 original requirement) ---
-keep class com.android.vending.billing.** { *; }

# --- tflite_flutter (Section 5, File 55 original requirement — restored
#     after being dropped in v1.2/1.3 when Path A was wrongly treated as
#     default; Path B is the actual v1 default, so this is required) ---
-keep class org.tensorflow.** { *; }
-keep class org.tensorflow.lite.** { *; }
-dontwarn org.tensorflow.**

# ============================================================
# Plugins added during Phases 2/5 (permission_handler, gal,
# flutter_image_compress, crop_your_image, sqflite, cross_file,
# url_launcher) do NOT have keep rules added here.
#
# Honest reasoning, not an oversight: I don't have verified internal
# package paths for most of these plugins' native Android
# implementations, and inventing plausible-looking package names for
# ProGuard rules would be worse than omitting them — a wrong rule gives
# false confidence, while a missing one at least fails loudly and
# specifically. Most modern Flutter plugins route through MethodChannel
# using string-based method names rather than reflection, so R8/ProGuard
# shrinking often doesn't break them without any extra rules at all.
#
# Correct next step: build a release APK/AAB via Section 15's checklist
# and exercise every feature that touches these plugins (camera
# permission flow, save-to-gallery, WEBP export, crop screen). If a
# release-mode crash log names a specific missing class
# (NoSuchMethodError / ClassNotFoundException), add a targeted -keep rule
# for that exact class then — informed by a real error, not a guess.
# ============================================================

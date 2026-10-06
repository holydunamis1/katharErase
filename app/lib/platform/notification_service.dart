import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../core/utils/constants.dart';

/// Local "you have an unfinished edit" reminder.
///
/// The reminder is scheduled as an absolute instant in UTC, which needs no
/// time-zone database. (Do NOT call tz.initializeTimeZones() here: parsing
/// the whole database is CPU-heavy and froze the first frame on slow
/// devices.)
///
/// Every method is failure-safe: a notification problem must never break
/// editing or exporting, so errors are logged and swallowed. Nothing is
/// scheduled until [init] has succeeded.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const int _unfinishedEditId = 1001;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _permissionAskedThisSession = false;

  bool get isInitialized => _initialized;

  Future<void> init() async {
    if (_initialized) return;
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      // Permission is requested explicitly later, at a sensible moment,
      // not as a surprise prompt at launch.
      const darwin = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _plugin.initialize(
        settings: const InitializationSettings(android: android, iOS: darwin),
      );
      _initialized = true;
    } catch (e) {
      debugPrint('Notification init failed: $e');
    }
  }

  /// Asks the OS for notification permission. Returns true if granted.
  Future<bool> requestPermission() async {
    if (!_initialized) return false;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        final granted = await android.requestNotificationsPermission();
        return granted ?? false;
      }
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        final granted = await ios.requestPermissions(
          alert: true,
          badge: false,
          sound: true,
        );
        return granted ?? false;
      }
      return false;
    } catch (e) {
      debugPrint('Notification permission request failed: $e');
      return false;
    }
  }

  /// Asks for permission at most once per app session, so opening the
  /// editor repeatedly never nags.
  Future<void> ensurePermissionOncePerSession() async {
    if (_permissionAskedThisSession) return;
    _permissionAskedThisSession = true;
    await requestPermission();
  }

  /// Schedules the reminder [kUnfinishedEditReminderDelay] from now,
  /// replacing any earlier one (same id). Uses an inexact alarm, so no
  /// special exact-alarm permission is needed.
  Future<void> scheduleUnfinishedEditReminder({
    required String title,
    required String body,
    required String channelName,
    required String channelDescription,
  }) async {
    if (!_initialized) return;
    try {
      final when = tz.TZDateTime.now(tz.UTC).add(kUnfinishedEditReminderDelay);
      await _plugin.zonedSchedule(
        id: _unfinishedEditId,
        title: title,
        body: body,
        scheduledDate: when,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            kReminderChannelId,
            channelName,
            channelDescription: channelDescription,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('Scheduling reminder failed: $e');
    }
  }

  Future<void> cancelUnfinishedEditReminder() async {
    if (!_initialized) return;
    try {
      await _plugin.cancel(id: _unfinishedEditId);
    } catch (e) {
      debugPrint('Cancelling reminder failed: $e');
    }
  }
}

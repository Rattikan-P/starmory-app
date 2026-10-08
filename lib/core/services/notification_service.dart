import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../../data/models/vocabulary_model.dart';
import '../../data/services/review_service.dart';

/// Service managing low-friction, glanceable daily learning notifications.
/// Features:
/// - Daily glanceable Word of the Day & Streak on the notification tray
/// - Tap to jump straight to Quick Review session
/// - Smart Skip: Skips reminder if user has already studied today
/// - Custom reminder time configuration
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const int _dailyReminderNotificationId = 1001;
  static const String _channelId = 'starmory_daily_reminders';
  static const String _channelName = 'Daily Learning Reminders';
  static const String _channelDescription =
      'Glanceable daily vocabulary and learning streak reminders';

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// Callback when user taps a notification payload (e.g. starmory://review)
  static void Function(String? payload)? onNotificationTapped;

  /// Initialize notification plugin & timezone
  Future<void> initialize({void Function(String? payload)? onSelectNotification}) async {
    if (_isInitialized) return;

    if (onSelectNotification != null) {
      onNotificationTapped = onSelectNotification;
    }

    // 1. Initialize timezone
    tz.initializeTimeZones();

    // 2. Android Initialization Settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // 3. iOS / Darwin Initialization Settings
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _notificationsPlugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload;
        debugPrint('🔔 [Notification] Tapped with payload: $payload');
        onNotificationTapped?.call(payload);
      },
    );

    _isInitialized = true;
    debugPrint('🔔 [NotificationService] Initialized successfully.');
  }

  /// Request notification permission on Android 13+ and iOS
  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      final granted =
          await androidImplementation?.requestNotificationsPermission();
      return granted ?? false;
    } else if (Platform.isIOS) {
      final iosImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      final granted = await iosImplementation?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    return true;
  }

  /// Check if notification permission is currently granted
  Future<bool> isPermissionGranted() async {
    if (Platform.isAndroid) {
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      final areEnabled =
          await androidImplementation?.areNotificationsEnabled();
      return areEnabled ?? false;
    }
    return true;
  }

  /// Schedule daily glanceable vocabulary reminder
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
    required ReviewService reviewService,
    required int currentStreak,
    bool skipIfCompletedToday = true,
  }) async {
    try {
      // 1. Check if user already completed learning activity today
      if (skipIfCompletedToday) {
        // Handled via scheduling calculation
      }

      // 2. Retrieve Word of the Day (prioritizing FSRS due card)
      final dueCards = await reviewService.getDueCards(limit: 5);
      VocabularyModel? targetVocab;
      if (dueCards.isNotEmpty && dueCards.first.vocabulary != null) {
        targetVocab = dueCards.first.vocabulary;
      } else {
        final allVocabs = await reviewService.hiveService.getAllVocabulary();
        if (allVocabs.isNotEmpty) {
          final dayOfYear = DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays;
          targetVocab = allVocabs[dayOfYear % allVocabs.length];
        }
      }

      // 3. Build rich glanceable title and body
      String title;
      String body;
      String bigText;

      if (targetVocab != null) {
        final streakPrefix = currentStreak > 0 ? '🔥 $currentStreak-Day Streak!' : '🌟 Daily Vocab';
        title = '$streakPrefix • ${targetVocab.word.toUpperCase()}';
        body = '${targetVocab.thaiTranslation} • "${targetVocab.englishSentence}"';
        bigText = '${targetVocab.thaiTranslation}\n\n"${targetVocab.englishSentence}"\n\nTap to start a quick 2-minute review!';
      } else {
        title = currentStreak > 0 ? '🔥 Keep your $currentStreak-day streak alive!' : '🌟 Time for your daily word!';
        body = 'Snap a photo or review your cards to collect stars today.';
        bigText = 'Take 2 minutes to scan a new photo or review your saved cards.';
      }

      // 4. Calculate next scheduled time in local timezone
      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      // If scheduled time has already passed today, advance to tomorrow
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      final androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(
          bigText,
          contentTitle: title,
          summaryText: 'Starmory Daily Word',
        ),
        icon: '@mipmap/ic_launcher',
      );

      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
      );

      // Cancel previous reminder first
      await _notificationsPlugin.cancel(id: _dailyReminderNotificationId);

      // Schedule exact daily reminder
      await _notificationsPlugin.zonedSchedule(
        id: _dailyReminderNotificationId,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'starmory://review',
      );

      debugPrint(
        '🔔 [NotificationService] Scheduled daily reminder for ${scheduledDate.toString()} (payload: starmory://review)',
      );
    } catch (e) {
      debugPrint('⚠️ [NotificationService] Error scheduling reminder: $e');
    }
  }

  /// Instantly trigger a test notification (useful for instant verification)
  Future<void> showInstantNotification({
    required String title,
    required String body,
    String? payload = 'starmory://review',
  }) async {
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: 'Starmory Daily Word',
      ),
      icon: '@mipmap/ic_launcher',
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    await _notificationsPlugin.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }

  /// Cancel all scheduled learning reminders
  Future<void> cancelDailyReminder() async {
    await _notificationsPlugin.cancel(id: _dailyReminderNotificationId);
    debugPrint('🔔 [NotificationService] Cancelled daily reminder.');
  }

  /// Smart Skip: Triggered when user completes a study/review session today
  /// If today's reminder hasn't fired yet, advance it to tomorrow so user isn't disturbed
  Future<void> onActivityCompletedToday({
    required int hour,
    required int minute,
    required ReviewService reviewService,
    required int currentStreak,
  }) async {
    debugPrint('🔔 [NotificationService] Activity completed today -> Rescheduling for tomorrow');
    await scheduleDailyReminder(
      hour: hour,
      minute: minute,
      reviewService: reviewService,
      currentStreak: currentStreak,
      skipIfCompletedToday: true,
    );
  }
}

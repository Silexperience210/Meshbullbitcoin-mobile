import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Service for managing broadcast notifications.
///
/// Shows persistent notification during transaction broadcast,
/// updates progress, and completes when done.
class BroadcastNotificationService {
  static final _notifications = FlutterLocalNotificationsPlugin();
  static const _channelId = 'disaster_tx_broadcast';
  static const _channelName = 'Transaction Broadcasting';
  static const _channelDescription = 'Shows progress when broadcasting transactions via LoRa';
  static const _notificationId = 1000;

  /// Initialize the notification service.
  static Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(settings);

    // Create notification channel (Android)
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.low, // Low importance to avoid sound
      showBadge: false,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  /// Show broadcast started notification.
  static Future<void> showBroadcastStarted({
    required String deviceName,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true, // Persistent notification
      autoCancel: false,
      showProgress: true,
      maxProgress: 100,
      progress: 0,
      playSound: false,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: false,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      _notificationId,
      'Broadcasting Transaction',
      'Sending via $deviceName...',
      details,
    );
  }

  /// Update broadcast progress.
  static Future<void> updateProgress({
    required double progress,
    required int currentChunk,
    required int totalChunks,
  }) async {
    final percentage = (progress * 100).toInt();

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showProgress: true,
      maxProgress: 100,
      progress: percentage,
      playSound: false,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: false,
      presentBadge: false,
      presentSound: false,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      _notificationId,
      'Broadcasting Transaction',
      'Chunk $currentChunk/$totalChunks ($percentage%)',
      details,
    );
  }

  /// Show broadcast completed notification.
  static Future<void> showBroadcastComplete() async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.low,
      priority: Priority.low,
      ongoing: false,
      autoCancel: true,
      playSound: false,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: false,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      _notificationId,
      'Transaction Broadcast Complete',
      'Successfully sent via LoRa mesh network',
      details,
    );

    // Auto-dismiss after 3 seconds
    await Future.delayed(const Duration(seconds: 3));
    await cancel();
  }

  /// Show broadcast error notification.
  static Future<void> showBroadcastError(String error) async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      ongoing: false,
      autoCancel: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      _notificationId,
      'Broadcast Failed',
      error,
      details,
    );
  }

  /// Cancel the notification.
  static Future<void> cancel() async {
    await _notifications.cancel(_notificationId);
  }
}

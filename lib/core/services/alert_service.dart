import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';

/// Manages local push notifications and vibration patterns for IV alerts.
/// Call [init] once at app startup before using other methods.
class AlertService {
  // Singleton — one instance shared across the app
  static final AlertService instance = AlertService._();
  AlertService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  final _tapStream = StreamController<String>.broadcast();

  static const _channelId = 'iv_sentinel_alerts';
  static const _channelName = 'IV Alerts';

  /// Tap payloads (bed config IDs) from notification taps. Listen in main.dart.
  Stream<String> get notificationTaps => _tapStream.stream;

  Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: androidInit),
      onDidReceiveNotificationResponse: (details) {
        if (details.payload != null) {
          _tapStream.add(details.payload!);
        }
      },
    );

    // Request POST_NOTIFICATIONS permission on Android 13+
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// CRITICAL: three strong bursts + max-priority notification.
  Future<void> fireCritical(String bedName, int percent, String bedConfigId) async {
    _vibrate([0, 500, 200, 500, 200, 500]);
    await _notify(
      id: bedConfigId.hashCode & 0x7FFFFFFF,
      title: 'CRITICAL — $bedName',
      body: 'Fluid at $percent%. Check immediately.',
      payload: bedConfigId,
      priority: Priority.max,
      importance: Importance.max,
    );
  }

  /// LOW: one medium pulse + high-priority notification.
  Future<void> fireLow(String bedName, int percent, String bedConfigId) async {
    _vibrate([0, 300, 500]);
    await _notify(
      // XOR with 1 so LOW and CRITICAL have distinct notification IDs for the same bed
      id: (bedConfigId.hashCode & 0x7FFFFFFF) ^ 1,
      title: 'LOW — $bedName',
      body: 'Fluid at $percent%. Monitor closely.',
      payload: bedConfigId,
      priority: Priority.high,
      importance: Importance.high,
    );
  }

  Future<void> _notify({
    required int id,
    required String title,
    required String body,
    required String payload,
    required Priority priority,
    required Importance importance,
  }) async {
    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: importance,
          priority: priority,
          // We drive vibration ourselves with custom patterns above
          enableVibration: false,
          playSound: true,
        ),
      ),
      payload: payload,
    );
  }

  void _vibrate(List<int> pattern) {
    Vibration.hasVibrator().then((has) {
      if (has == true) Vibration.vibrate(pattern: pattern);
    });
  }
}

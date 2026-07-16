import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';

/// Manages local push notifications and vibration patterns for IV alerts.
/// Call [init] once at app startup before using other methods.
class AlertService {
  static final AlertService instance = AlertService._();
  AlertService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  final _tapStream = StreamController<String>.broadcast();

  // Stores a tap payload that fired before any listener subscribed (cold-launch)
  String? _pendingTapPayload;

  static const _channelId = 'iv_sentinel_alerts';
  static const _channelName = 'IV Alerts';

  /// Stream of bed config IDs from notification taps. Listen in main.dart.
  Stream<String> get notificationTaps => _tapStream.stream;

  /// Returns and clears a tap that arrived before the stream had a listener.
  /// Call this in initState to handle cold-launch notification taps.
  String? consumePendingTap() {
    final p = _pendingTapPayload;
    _pendingTapPayload = null;
    return p;
  }

  Future<void> init() async {
    // flutter_local_notifications has no web/Windows/macOS/Linux implementation
    // in this project — skip plugin init on unsupported platforms so it can
    // never throw and block app startup.
    if (kIsWeb ||
        !(defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      return;
    }

    try {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      await _plugin.initialize(
        const InitializationSettings(android: androidInit),
        onDidReceiveNotificationResponse: (details) {
          if (details.payload == null) return;
          if (_tapStream.hasListener) {
            _tapStream.add(details.payload!);
          } else {
            // App was cold-launched via notification — store for initState to consume
            _pendingTapPayload = details.payload;
          }
        },
      );

      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    } catch (e, st) {
      // Never let a notification-plugin failure block app startup.
      debugPrint('AlertService.init failed: $e\n$st');
    }
  }

  /// CRITICAL alert: three strong bursts + max-priority notification.
  /// [notify] and [vibrate] are driven by the user's Settings preferences.
  Future<void> fireCritical(
    String bedName,
    int percent,
    String bedConfigId, {
    required bool notify,
    required bool vibrate,
  }) async {
    if (vibrate) _vibrate([0, 500, 200, 500, 200, 500]);
    if (notify) {
      await _notify(
        id: bedConfigId.hashCode & 0x7FFFFFFF,
        title: 'CRITICAL — $bedName',
        body: 'Fluid at $percent%. Check immediately.',
        payload: bedConfigId,
        priority: Priority.max,
        importance: Importance.max,
      );
    }
  }

  /// LOW alert: one medium pulse + high-priority notification.
  Future<void> fireLow(
    String bedName,
    int percent,
    String bedConfigId, {
    required bool notify,
    required bool vibrate,
  }) async {
    if (vibrate) _vibrate([0, 300, 500]);
    if (notify) {
      await _notify(
        id: (bedConfigId.hashCode & 0x7FFFFFFF) ^ 1,
        title: 'LOW — $bedName',
        body: 'Fluid at $percent%. Monitor closely.',
        payload: bedConfigId,
        priority: Priority.high,
        importance: Importance.high,
      );
    }
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
          enableVibration: false, // custom patterns handled above
          playSound: true,
        ),
      ),
      payload: payload,
    );
  }

  void _vibrate(List<int> pattern) {
    Vibration.hasVibrator()
        .then((has) {
          if (has == true) Vibration.vibrate(pattern: pattern);
        })
        .catchError((e) {
          debugPrint('Vibration failed: $e');
        });
  }
}

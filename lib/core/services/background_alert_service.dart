import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bed_config.dart';
import 'alert_service.dart';
import 'polling_engine.dart';

// Must match the keys in bed_config_notifier.dart — the background isolate
// has no access to Riverpod's provider container, so settings are read
// directly from the same SharedPreferences store instead.
const _kBedsKey = 'iv_sentinel_beds';
const _kVibrationKey = 'iv_sentinel_vibration';
const _kNotificationsKey = 'iv_sentinel_notifications';

// Background polling runs on a fixed, battery-conscious cadence regardless
// of the in-app (foreground) poll interval, which can be as low as 1s.
const _backgroundPollInterval = Duration(seconds: 15);

const _foregroundChannelId = 'iv_sentinel_background';
const _foregroundChannelName = 'IV Sentinel Monitoring';

/// Wraps `flutter_background_service` so the rest of the app only has to
/// call [start]/[stop]. The service keeps polling ThingSpeak and firing
/// CRITICAL/LOW alerts while the app is backgrounded, using a persistent
/// low-priority notification as required by Android to stay alive.
class BackgroundAlertService {
  BackgroundAlertService._();
  static final instance = BackgroundAlertService._();

  final _service = FlutterBackgroundService();
  bool _configured = false;

  Future<void> configure() async {
    if (_configured) return;
    _configured = true;

    // The notification channel must exist before service.configure() runs —
    // flutter_background_service does not create it for you.
    const channel = AndroidNotificationChannel(
      _foregroundChannelId,
      _foregroundChannelName,
      description: 'Ongoing IV fluid monitoring while the app is backgrounded.',
      importance: Importance.low,
    );
    await FlutterLocalNotificationsPlugin()
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        isForegroundMode: true,
        autoStart: false,
        notificationChannelId: _foregroundChannelId,
        initialNotificationTitle: 'IV Sentinel',
        initialNotificationContent: 'Monitoring paused',
        foregroundServiceNotificationId: 888,
        foregroundServiceTypes: [AndroidForegroundType.dataSync],
      ),
      iosConfiguration: IosConfiguration(),
    );
  }

  Future<void> start() async {
    if (!await _service.isRunning()) {
      await _service.startService();
    }
  }

  /// Stops the background service and waits for it to actually finish
  /// stopping (up to 2s) before returning. The caller (main.dart, on app
  /// resume) relies on this: it resumes the foreground poller right after
  /// `stop()` returns, and if the background isolate were still mid-tick,
  /// both pollers would briefly run at once and could double-fire an alert.
  Future<void> stop() async {
    if (!await _service.isRunning()) return;
    _service.invoke('stopService');
    for (var i = 0; i < 20 && await _service.isRunning(); i++) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }
}

@pragma('vm:entry-point')
Future<void> _onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    service.on('stopService').listen((_) => service.stopSelf());
  }

  await AlertService.instance.init();
  final engine = PollingEngine();

  // Pick up exactly where the foreground poller left off (see
  // BedReadingsNotifier.pauseForBackground) so a bed already LOW/CRITICAL
  // doesn't look like a fresh transition just because polling moved isolates.
  final startupPrefs = await SharedPreferences.getInstance();
  await engine.restorePrevStatus(startupPrefs);

  Future<void> tick() async {
    final prefs = await SharedPreferences.getInstance();

    final bedsJson = prefs.getString(_kBedsKey);
    final beds = bedsJson == null
        ? <BedConfig>[]
        : (jsonDecode(bedsJson) as List)
            .map((e) => BedConfig.fromJson(e as Map<String, dynamic>))
            .toList();

    if (beds.isEmpty) return;

    final vibrationEnabled = prefs.getBool(_kVibrationKey) ?? true;
    final notificationsEnabled = prefs.getBool(_kNotificationsKey) ?? true;

    engine.pruneRemovedBeds(beds);
    final fresh = await engine.fetchAll(beds, const {});
    await engine.evaluateAlerts(
      beds,
      fresh,
      notificationsEnabled: notificationsEnabled,
      vibrationEnabled: vibrationEnabled,
    );
    // Keep the handoff state current in case the process is killed outright
    // (no clean stop() call) or the foreground resumes and reads it next.
    await engine.persistPrevStatus(prefs);

    if (service is AndroidServiceInstance && await service.isForegroundService()) {
      final criticalCount = fresh.values.where((r) => r.isCritical).length;
      final lowCount = fresh.values.where((r) => r.isLow).length;
      final summary = criticalCount > 0
          ? '$criticalCount bed(s) CRITICAL'
          : lowCount > 0
              ? '$lowCount bed(s) LOW'
              : 'All beds normal';
      service.setForegroundNotificationInfo(
        title: 'IV Sentinel — monitoring active',
        content: summary,
      );
    }
  }

  await tick();
  Timer.periodic(_backgroundPollInterval, (_) => tick());
}

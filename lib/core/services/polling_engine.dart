import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bed_config.dart';
import '../models/bed_reading.dart';
import 'alert_service.dart';
import 'connectivity_service.dart';
import 'thingspeak_service.dart';

// Shared between the foreground and background pollers so a transition seen
// by one side isn't re-detected (and re-alerted) by the other after a
// foreground<->background handoff, since each runs its own PollingEngine
// instance in a separate isolate.
const kPrevStatusPrefsKey = 'iv_sentinel_prev_status';

/// Shared fetch + alert-evaluation logic used by both the foreground
/// (in-app) poller and the background foreground-service poller. Each side
/// owns its own instance — they run in separate Dart isolates and cannot
/// share a single object — but keeping the logic here means a fix only has
/// to happen once.
class PollingEngine {
  PollingEngine({ThingSpeakService? service, ConnectivityService? connectivity})
      : _service = service ?? ThingSpeakService(),
        _connectivity = connectivity ?? ConnectivityService.instance;

  final ThingSpeakService _service;
  final ConnectivityService _connectivity;

  final Map<String, int> _prevStatus = {};
  final Set<String> _erroredBeds = {};

  bool _deviceOffline = false;
  bool get isDeviceOffline => _deviceOffline;
  bool hasError(String bedId) => _erroredBeds.contains(bedId);

  void pruneRemovedBeds(List<BedConfig> beds) {
    _prevStatus.removeWhere((id, _) => !beds.any((b) => b.id == id));
  }

  /// Persists the current transition-tracking state so the other poller
  /// (foreground or background) can pick up exactly where this one left off
  /// instead of starting from a blank slate and re-alerting on beds that are
  /// already LOW/CRITICAL.
  Future<void> persistPrevStatus(SharedPreferences prefs) async {
    await prefs.setString(kPrevStatusPrefsKey, jsonEncode(_prevStatus));
  }

  Future<void> restorePrevStatus(SharedPreferences prefs) async {
    final raw = prefs.getString(kPrevStatusPrefsKey);
    if (raw == null) return;
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    _prevStatus
      ..clear()
      ..addAll(decoded.map((k, v) => MapEntry(k, v as int)));
  }

  /// Fetches all beds in parallel. A single bed failure does NOT wipe
  /// others — the previous reading is preserved for any bed whose fetch
  /// throws. [previous] seeds the result so callers control what
  /// last-known state looks like (e.g. current provider state).
  Future<Map<String, BedReading>> fetchAll(
    List<BedConfig> beds,
    Map<String, BedReading> previous,
  ) async {
    if (beds.isEmpty) return {};

    final result = Map<String, BedReading>.from(previous);

    _deviceOffline = !await _connectivity.isOnline();

    await Future.wait(
      beds.map((bed) async {
        if (_deviceOffline) {
          _erroredBeds.add(bed.id);
          return;
        }
        try {
          result[bed.id] = await _service.fetchLatest(bed.channelId, bed.apiKey);
          _erroredBeds.remove(bed.id);
        } on ThingSpeakRateLimitException {
          // Throttled — keep the last-known reading, retry next tick.
        } catch (e) {
          _erroredBeds.add(bed.id);
          debugPrint('ThingSpeak fetch failed for ${bed.id}: $e');
        }
      }),
    );

    return result;
  }

  /// Compares each bed's new status against its last-known status and fires
  /// vibration/notifications on entering LOW or CRITICAL.
  Future<void> evaluateAlerts(
    List<BedConfig> beds,
    Map<String, BedReading> fresh, {
    required bool notificationsEnabled,
    required bool vibrationEnabled,
  }) async {
    for (final bed in beds) {
      final reading = fresh[bed.id];
      if (reading == null) continue;

      final prev = _prevStatus[bed.id];
      final curr = reading.statusCode;

      if (prev != curr) {
        try {
          if (curr == 2) {
            await AlertService.instance.fireCritical(
              bed.name,
              reading.percent.toInt(),
              bed.id,
              notify: notificationsEnabled,
              vibrate: vibrationEnabled,
            );
          } else if (curr == 1 && (prev == null || prev == 0)) {
            await AlertService.instance.fireLow(
              bed.name,
              reading.percent.toInt(),
              bed.id,
              notify: notificationsEnabled,
              vibrate: vibrationEnabled,
            );
          }
        } catch (_) {
          // Never let a notification/vibration failure affect displayed data.
        }
      }

      _prevStatus[bed.id] = curr;
    }
  }
}

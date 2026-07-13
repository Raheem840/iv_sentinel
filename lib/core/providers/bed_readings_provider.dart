import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/bed_reading.dart';
import '../services/thingspeak_service.dart';
import '../services/alert_service.dart';
import '../../features/settings/bed_config_notifier.dart';

/// Holds the latest reading for every configured bed, keyed by bed config ID.
/// Fires alerts when a bed transitions into CRITICAL or LOW status.
class BedReadingsNotifier extends AsyncNotifier<Map<String, BedReading>> {
  final _service = ThingSpeakService();
  Timer? _timer;

  // Tracks the previous status per bed to detect transitions (not just current state)
  final Map<String, int> _prevStatus = {};

  @override
  Future<Map<String, BedReading>> build() async {
    ref.onDispose(() => _timer?.cancel());

    // Only rebuild polling machinery when beds list or interval changes —
    // not on cosmetic settings changes like dark mode or vibration toggle.
    final beds = ref.watch(appSettingsProvider.select((s) => s.beds));
    final interval = ref.watch(
      appSettingsProvider.select((s) => s.pollIntervalSeconds),
    );

    _timer = Timer.periodic(Duration(seconds: interval), (_) => _poll());

    // Remove history for beds that no longer exist
    _prevStatus.removeWhere((id, _) => !beds.any((b) => b.id == id));

    return _fetchAll();
  }

  /// Manual refresh — shows loading spinner, then refetches.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetchAll);
  }

  /// Fetches all beds in parallel. A single bed failure does NOT wipe others —
  /// the previous reading is preserved for any bed whose fetch throws.
  Future<Map<String, BedReading>> _fetchAll() async {
    final beds = ref.read(appSettingsProvider).beds;
    if (beds.isEmpty) return {};

    // Start with whatever we already have so failures keep last-known values
    final result = Map<String, BedReading>.from(state.valueOrNull ?? {});

    // Run all fetches concurrently; catch per-bed so one failure is isolated
    await Future.wait(
      beds.map((bed) async {
        try {
          result[bed.id] = await _service.fetchLatest(bed.channelId, bed.apiKey);
        } catch (_) {
          // Keep the previous reading for this bed; don't disrupt other beds
        }
      }),
    );

    return result;
  }

  /// Timer tick — updates state without a full loading-spinner cycle.
  Future<void> _poll() async {
    try {
      final settings = ref.read(appSettingsProvider);
      final fresh = await _fetchAll();

      // Evaluate status transitions and fire per-feature alerts
      for (final bed in settings.beds) {
        final reading = fresh[bed.id];
        if (reading == null) continue;

        final prev = _prevStatus[bed.id];
        final curr = reading.statusCode;

        if (prev != curr) {
          if (curr == 2) {
            // Entered CRITICAL — fire notification and/or vibration based on user prefs
            await AlertService.instance.fireCritical(
              bed.name,
              reading.percent.toInt(),
              bed.id,
              notify: settings.notificationsEnabled,
              vibrate: settings.vibrationEnabled,
            );
          } else if (curr == 1 && (prev == null || prev == 0)) {
            // Entered LOW from normal (don't re-alert when coming down from CRITICAL)
            await AlertService.instance.fireLow(
              bed.name,
              reading.percent.toInt(),
              bed.id,
              notify: settings.notificationsEnabled,
              vibrate: settings.vibrationEnabled,
            );
          }
        }

        _prevStatus[bed.id] = curr;
      }

      state = AsyncData(fresh);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

final bedReadingsProvider =
    AsyncNotifierProvider<BedReadingsNotifier, Map<String, BedReading>>(
  BedReadingsNotifier.new,
);

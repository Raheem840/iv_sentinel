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

    final settings = ref.watch(appSettingsProvider);

    _timer = Timer.periodic(
      Duration(seconds: settings.pollIntervalSeconds),
      (_) => _poll(),
    );

    return _fetchAll();
  }

  /// Called by refresh buttons and the timer.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetchAll);
  }

  Future<Map<String, BedReading>> _fetchAll() async {
    final beds = ref.read(appSettingsProvider).beds;
    if (beds.isEmpty) return {};

    // Fetch all beds in parallel
    final results = await Future.wait(
      beds.map((bed) => _service.fetchLatest(bed.channelId, bed.apiKey)),
    );

    return {for (var i = 0; i < beds.length; i++) beds[i].id: results[i]};
  }

  Future<void> _poll() async {
    try {
      final settings = ref.read(appSettingsProvider);
      final fresh = await _fetchAll();

      // Check each bed for status transitions and fire alerts if needed
      if (settings.notificationsEnabled || settings.vibrationEnabled) {
        for (final bed in settings.beds) {
          final reading = fresh[bed.id];
          if (reading == null) continue;

          final prev = _prevStatus[bed.id];
          final curr = reading.statusCode;

          // Only alert on entry into CRITICAL or LOW (not on every poll)
          if (prev != curr) {
            if (curr == 2) {
              // Entered CRITICAL
              await AlertService.instance.fireCritical(
                bed.name, reading.percent.toInt(), bed.id,
              );
            } else if (curr == 1 && (prev == null || prev == 0)) {
              // Entered LOW (only from normal — avoid re-alerting if coming down from critical)
              await AlertService.instance.fireLow(
                bed.name, reading.percent.toInt(), bed.id,
              );
            }
          }

          _prevStatus[bed.id] = curr;
        }
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

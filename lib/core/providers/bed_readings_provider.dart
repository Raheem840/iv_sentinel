import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/bed_reading.dart';
import '../services/thingspeak_service.dart';
import '../../features/settings/bed_config_notifier.dart';

/// Holds the latest reading for every configured bed, keyed by bed config ID.
/// Automatically refreshes on a timer using the poll interval from settings.
class BedReadingsNotifier extends AsyncNotifier<Map<String, BedReading>> {
  final _service = ThingSpeakService();
  Timer? _timer;

  @override
  Future<Map<String, BedReading>> build() async {
    // When settings change (beds added/removed or poll interval changes),
    // Riverpod rebuilds this notifier — cancel the old timer first.
    ref.onDispose(() => _timer?.cancel());

    final settings = ref.watch(appSettingsProvider);

    // Start the recurring poll timer
    _timer = Timer.periodic(
      Duration(seconds: settings.pollIntervalSeconds),
      (_) => _poll(),
    );

    // Fetch immediately on first build so the UI isn't blank
    return _fetchAll();
  }

  /// Called by the timer and by manual refresh buttons.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetchAll);
  }

  /// Fetches the latest reading for every configured bed in parallel.
  Future<Map<String, BedReading>> _fetchAll() async {
    final beds = ref.read(appSettingsProvider).beds;
    if (beds.isEmpty) return {};

    // Run all HTTP calls concurrently (not one-by-one) to stay within the poll window
    final results = await Future.wait(
      beds.map((bed) => _service.fetchLatest(bed.channelId, bed.apiKey)),
    );

    // Map each result back to the bed config's ID (not the hardware's field3 ID)
    // so the UI can look it up by the same ID used in BedConfig.
    return {for (var i = 0; i < beds.length; i++) beds[i].id: results[i]};
  }

  /// Timer tick — silently updates state without showing a loading spinner.
  Future<void> _poll() async {
    try {
      final fresh = await _fetchAll();
      // Only update if we're not already in an error state from a previous failure
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

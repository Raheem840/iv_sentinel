import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bed_reading.dart';
import '../services/polling_engine.dart';
import '../../features/settings/bed_config_notifier.dart';

/// Holds the latest reading for every configured bed, keyed by bed config ID.
/// Fires alerts when a bed transitions into CRITICAL or LOW status.
class BedReadingsNotifier extends AsyncNotifier<Map<String, BedReading>> {
  final _engine = PollingEngine();
  Timer? _timer;

  // While true, build()/rebuilds must not recreate the timer — the app is
  // backgrounded and BackgroundAlertService owns polling until resumeFromBackground().
  bool _pausedForBackground = false;

  bool get isDeviceOffline => _engine.isDeviceOffline;
  bool hasError(String bedId) => _engine.hasError(bedId);

  @override
  Future<Map<String, BedReading>> build() async {
    ref.onDispose(() => _timer?.cancel());

    // Only rebuild polling machinery when beds list or interval changes —
    // not on cosmetic settings changes like dark mode or vibration toggle.
    final beds = ref.watch(appSettingsProvider.select((s) => s.beds));
    final interval = ref.watch(
      appSettingsProvider.select((s) => s.pollIntervalSeconds),
    );

    _engine.pruneRemovedBeds(beds);

    if (!_pausedForBackground) {
      _timer?.cancel();
      _timer = Timer.periodic(Duration(seconds: interval), (_) => _poll());
    }

    final fresh = await _fetchAll();
    // Evaluate alerts on the very first fetch too — otherwise a bed that's
    // already LOW/CRITICAL the moment it's added has to wait up to a full
    // poll interval (1-60s) before anything vibrates or notifies.
    await _evaluateAlerts(fresh);
    return fresh;
  }

  /// Called when the app backgrounds, right before BackgroundAlertService
  /// starts. Stops this timer (Android does not reliably suspend
  /// Timer.periodic just because the app is paused) and hands off the
  /// transition-tracking state so the background poller doesn't re-alert on
  /// beds that are already LOW/CRITICAL.
  Future<void> pauseForBackground() async {
    _pausedForBackground = true;
    _timer?.cancel();
    _timer = null;
    final prefs = await SharedPreferences.getInstance();
    await _engine.persistPrevStatus(prefs);
  }

  /// Called when the app resumes, right after BackgroundAlertService has
  /// been confirmed stopped. Restores whatever transition state the
  /// background poller left behind and polls immediately so the UI reflects
  /// what happened while backgrounded without waiting a full interval.
  Future<void> resumeFromBackground() async {
    _pausedForBackground = false;
    final prefs = await SharedPreferences.getInstance();
    await _engine.restorePrevStatus(prefs);

    final interval = ref.read(
      appSettingsProvider.select((s) => s.pollIntervalSeconds),
    );
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: interval), (_) => _poll());
    await _poll();
  }

  /// Manual refresh — refetches while keeping the previous data available via
  /// `.valueOrNull` (via copyWithPrevious) so the UI can keep the real grid
  /// mounted (and its RefreshIndicator/scroll position intact) instead of
  /// tearing it down for a generic loading skeleton mid-refresh.
  Future<void> refresh() async {
    state = AsyncLoading<Map<String, BedReading>>().copyWithPrevious(state);
    state = await AsyncValue.guard(_fetchAll);
  }

  Future<Map<String, BedReading>> _fetchAll() async {
    final beds = ref.read(appSettingsProvider).beds;
    return _engine.fetchAll(beds, state.valueOrNull ?? {});
  }

  /// Timer tick — updates state without a full loading-spinner cycle.
  Future<void> _poll() async {
    final Map<String, BedReading> fresh;
    try {
      fresh = await _fetchAll();
    } catch (e, st) {
      state = AsyncError(e, st);
      return;
    }

    // Publish the fetch result immediately — alert delivery below must never
    // block or override data that was successfully retrieved.
    state = AsyncData(fresh);
    await _evaluateAlerts(fresh);
  }

  Future<void> _evaluateAlerts(Map<String, BedReading> fresh) async {
    final settings = ref.read(appSettingsProvider);
    await _engine.evaluateAlerts(
      settings.beds,
      fresh,
      notificationsEnabled: settings.notificationsEnabled,
      vibrationEnabled: settings.vibrationEnabled,
    );
  }
}

final bedReadingsProvider =
    AsyncNotifierProvider<BedReadingsNotifier, Map<String, BedReading>>(
      BedReadingsNotifier.new,
    );

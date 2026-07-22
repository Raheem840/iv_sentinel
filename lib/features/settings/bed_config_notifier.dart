import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/models/bed_config.dart';
import '../../core/services/secure_key_store.dart';

const _kBedsKey = 'iv_sentinel_beds';
const _kPollIntervalKey = 'iv_sentinel_poll_interval';
const _kVibrationKey = 'iv_sentinel_vibration';
const _kNotificationsKey = 'iv_sentinel_notifications';
const _kDarkModeKey = 'iv_sentinel_dark_mode';

// The state this notifier manages
class AppSettings {
  final List<BedConfig> beds;
  final int pollIntervalSeconds;
  final bool vibrationEnabled;
  final bool notificationsEnabled;
  final bool darkMode;

  const AppSettings({
    this.beds = const [],
    this.pollIntervalSeconds = 1,
    this.vibrationEnabled = true,
    this.notificationsEnabled = true,
    this.darkMode = true,
  });

  AppSettings copyWith({
    List<BedConfig>? beds,
    int? pollIntervalSeconds,
    bool? vibrationEnabled,
    bool? notificationsEnabled,
    bool? darkMode,
  }) {
    return AppSettings(
      beds: beds ?? this.beds,
      pollIntervalSeconds: pollIntervalSeconds ?? this.pollIntervalSeconds,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      darkMode: darkMode ?? this.darkMode,
    );
  }
}

class AppSettingsNotifier extends StateNotifier<AppSettings> {
  AppSettingsNotifier() : super(const AppSettings()) {
    _load();
  }

  // Load persisted settings from device storage on startup
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();

    final bedsJson = prefs.getString(_kBedsKey);
    final rawBeds = bedsJson == null
        ? <BedConfig>[]
        : (jsonDecode(bedsJson) as List)
            .map((e) => BedConfig.fromJson(e as Map<String, dynamic>))
            .toList();

    // API keys live in encrypted storage, keyed by bed ID, not in this blob.
    // A bed whose key is still found inline here is from before this
    // migration — move it to encrypted storage now and strip the blob once.
    var needsMigration = false;
    final beds = <BedConfig>[];
    for (final bed in rawBeds) {
      final secureKey = await SecureKeyStore.instance.read(bed.id);
      if (secureKey != null) {
        beds.add(bed.copyWith(apiKey: secureKey));
      } else if (bed.apiKey.isNotEmpty) {
        await SecureKeyStore.instance.write(bed.id, bed.apiKey);
        beds.add(bed);
        needsMigration = true;
      } else {
        beds.add(bed);
      }
    }

    state = AppSettings(
      beds: beds,
      pollIntervalSeconds: prefs.getInt(_kPollIntervalKey) ?? 1,
      vibrationEnabled: prefs.getBool(_kVibrationKey) ?? true,
      notificationsEnabled: prefs.getBool(_kNotificationsKey) ?? true,
      darkMode: prefs.getBool(_kDarkModeKey) ?? true,
    );

    if (needsMigration) await _saveBeds();
  }

  Future<void> _saveBeds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kBedsKey,
      jsonEncode(
        state.beds.map((b) => b.copyWith(apiKey: '').toJson()).toList(),
      ),
    );
  }

  Future<void> addBed(BedConfig bed) async {
    await SecureKeyStore.instance.write(bed.id, bed.apiKey);
    state = state.copyWith(beds: [...state.beds, bed]);
    await _saveBeds();
  }

  Future<void> updateBed(BedConfig updated) async {
    await SecureKeyStore.instance.write(updated.id, updated.apiKey);
    state = state.copyWith(
      beds: state.beds.map((b) => b.id == updated.id ? updated : b).toList(),
    );
    await _saveBeds();
  }

  Future<void> removeBed(String id) async {
    await SecureKeyStore.instance.delete(id);
    state = state.copyWith(beds: state.beds.where((b) => b.id != id).toList());
    await _saveBeds();
  }

  Future<void> setPollInterval(int seconds) async {
    state = state.copyWith(pollIntervalSeconds: seconds.clamp(1, 60));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kPollIntervalKey, state.pollIntervalSeconds);
  }

  Future<void> setVibration(bool enabled) async {
    state = state.copyWith(vibrationEnabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kVibrationKey, enabled);
  }

  Future<void> setNotifications(bool enabled) async {
    state = state.copyWith(notificationsEnabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kNotificationsKey, enabled);
  }

  Future<void> setDarkMode(bool enabled) async {
    state = state.copyWith(darkMode: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDarkModeKey, enabled);
  }
}

// The provider — any widget can read this anywhere in the app
final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettings>(
  (ref) => AppSettingsNotifier(),
);

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/bed_reading.dart';
import '../models/bed_config.dart';
import '../services/thingspeak_service.dart';

/// Fetches the last 60 readings for a single bed (used by the Detail screen chart).
/// ".family" means one provider instance is created per unique [BedConfig] argument.
final bedHistoryProvider = FutureProvider.family<List<BedReading>, BedConfig>(
  (ref, bedConfig) async {
    final service = ThingSpeakService();
    return service.fetchHistory(bedConfig.channelId, bedConfig.apiKey, results: 60);
  },
);

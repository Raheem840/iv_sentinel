import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/bed_reading.dart';

/// Thrown when ThingSpeak returns HTTP 429 (rate limited). Distinguished from
/// other failures so callers can keep showing last-known data instead of
/// treating a throttled poll tick as "no data".
class ThingSpeakRateLimitException implements Exception {
  final String message;
  ThingSpeakRateLimitException(this.message);
  @override
  String toString() => message;
}

/// Handles all communication with the ThingSpeak REST API.
/// Each ThingSpeak channel maps to one physical bed.
class ThingSpeakService {
  static const _base = 'https://api.thingspeak.com';

  /// Fetches the single most-recent reading for one channel.
  /// field1 = fluid %, field2 = status code (0/1/2), field3 = bed ID string.
  Future<BedReading> fetchLatest(String channelId, String apiKey) async {
    final uri = Uri.parse('$_base/channels/$channelId/feeds/last.json');

    // Sent as a header rather than a query param so the key doesn't end up
    // in plaintext in HTTP proxy/server access logs.
    final response = await http
        .get(uri, headers: {'X-THINGSPEAKAPIKEY': apiKey})
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 429) {
      throw ThingSpeakRateLimitException('ThingSpeak rate limit hit for channel $channelId');
    }
    if (response.statusCode != 200) {
      throw Exception('ThingSpeak error ${response.statusCode} for channel $channelId');
    }

    final decoded = jsonDecode(response.body);

    // ThingSpeak returns a bare "-1" (not a JSON object) for feeds/last.json
    // when the channel has a valid key but no entries have been published yet.
    if (decoded is! Map<String, dynamic>) {
      throw Exception('No data published yet for channel $channelId');
    }

    return _parseEntry(decoded, channelId);
  }

  /// Fetches the last [results] readings for the detail-screen chart.
  Future<List<BedReading>> fetchHistory(
    String channelId,
    String apiKey, {
    int results = 60,
  }) async {
    final uri = Uri.parse(
      '$_base/channels/$channelId/feeds.json?results=$results',
    );

    final response = await http
        .get(uri, headers: {'X-THINGSPEAKAPIKEY': apiKey})
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 429) {
      throw ThingSpeakRateLimitException('ThingSpeak rate limit hit for channel $channelId');
    }
    if (response.statusCode != 200) {
      throw Exception('ThingSpeak error ${response.statusCode} for channel $channelId');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    // ThingSpeak returns HTTP 200 with {"status":"error",...} for bad channel IDs/keys
    if (body['feeds'] == null) {
      throw Exception(
        'ThingSpeak returned no feeds for channel $channelId — check channel ID and API key',
      );
    }

    final feeds = body['feeds'] as List<dynamic>;

    // Parse each feed entry; skip any that have null/missing fields
    return feeds
        .map((e) => _tryParseEntry(e as Map<String, dynamic>, channelId))
        .whereType<BedReading>() // drops nulls from malformed entries
        .toList();
  }

  /// Converts a single ThingSpeak feed entry JSON object into a BedReading.
  BedReading _parseEntry(Map<String, dynamic> entry, String fallbackBedId) {
    // field3 is the bed ID the hardware stamps on each reading.
    // Fall back to the channel ID string if the hardware omits it.
    final bedId = (entry['field3'] as String?)?.trim().isNotEmpty == true
        ? entry['field3'] as String
        : fallbackBedId;

    final percent = double.tryParse(entry['field1'] as String? ?? '') ?? 0.0;
    final statusCode = int.tryParse(entry['field2'] as String? ?? '') ?? 0;

    // ThingSpeak timestamps are UTC ISO-8601: "2024-01-15T10:30:00Z"
    final timestamp = DateTime.tryParse(entry['created_at'] as String? ?? '') ??
        DateTime.now();

    return BedReading(
      bedId: bedId,
      percent: percent.clamp(0, 100),
      statusCode: statusCode.clamp(0, 2),
      timestamp: timestamp,
    );
  }

  /// Same as [_parseEntry] but returns null on any parse failure.
  BedReading? _tryParseEntry(Map<String, dynamic> entry, String fallbackBedId) {
    try {
      return _parseEntry(entry, fallbackBedId);
    } catch (_) {
      return null;
    }
  }
}

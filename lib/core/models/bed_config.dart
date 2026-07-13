import 'package:flutter/foundation.dart';

@immutable
class BedConfig {
  final String id;
  final String name;
  final String channelId;
  final String apiKey;
  final double lowThreshold;
  final double critThreshold;

  const BedConfig({
    required this.id,
    required this.name,
    required this.channelId,
    required this.apiKey,
    this.lowThreshold = 30.0,
    this.critThreshold = 15.0,
  });

  BedConfig copyWith({
    String? id,
    String? name,
    String? channelId,
    String? apiKey,
    double? lowThreshold,
    double? critThreshold,
  }) {
    return BedConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      channelId: channelId ?? this.channelId,
      apiKey: apiKey ?? this.apiKey,
      lowThreshold: lowThreshold ?? this.lowThreshold,
      critThreshold: critThreshold ?? this.critThreshold,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'channelId': channelId,
        'apiKey': apiKey,
        'lowThreshold': lowThreshold,
        'critThreshold': critThreshold,
      };

  factory BedConfig.fromJson(Map<String, dynamic> json) => BedConfig(
        id: json['id'] as String,
        name: json['name'] as String,
        channelId: json['channelId'] as String,
        apiKey: json['apiKey'] as String,
        lowThreshold: (json['lowThreshold'] as num?)?.toDouble() ?? 30.0,
        critThreshold: (json['critThreshold'] as num?)?.toDouble() ?? 15.0,
      );
}

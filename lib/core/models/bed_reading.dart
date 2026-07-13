import 'package:flutter/foundation.dart';

@immutable
class BedReading {
  final String bedId;
  final double percent;
  final int statusCode; // 0=normal, 1=low, 2=critical
  final DateTime timestamp;

  const BedReading({
    required this.bedId,
    required this.percent,
    required this.statusCode,
    required this.timestamp,
  });

  // Convenience getters so UI code doesn't need to remember what "2" means
  bool get isNormal => statusCode == 0;
  bool get isLow => statusCode == 1;
  bool get isCritical => statusCode == 2;
}

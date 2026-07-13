import 'package:flutter/material.dart';
import 'app_colors.dart';

// ThingSpeak field2 codes: 0 = normal, 1 = low, 2 = critical
Color statusColor(int code) {
  switch (code) {
    case 1:
      return kStatusAmber;
    case 2:
      return kStatusRed;
    default:
      return kStatusGreen;
  }
}

Color statusColorDim(int code) {
  switch (code) {
    case 1:
      return kStatusAmberDim;
    case 2:
      return kStatusRedDim;
    default:
      return kStatusGreenDim;
  }
}

String statusLabel(int code) {
  switch (code) {
    case 1:
      return 'LOW';
    case 2:
      return 'CRITICAL';
    default:
      return 'NORMAL';
  }
}

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/status_color.dart';

/// Small pill badge showing NORMAL / LOW / CRITICAL with the matching status color.
/// When [unknown] is true (no reading has been received yet), shows a neutral
/// "NO DATA" pill instead of implying a fake NORMAL/green status.
class StatusBadge extends StatelessWidget {
  final int statusCode;
  final bool small;
  final bool unknown;

  const StatusBadge({
    super.key,
    required this.statusCode,
    this.small = false,
    this.unknown = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = unknown ? kTextSecondaryDark : statusColor(statusCode);
    final label = unknown ? 'NO DATA' : statusLabel(statusCode);
    final fontSize = small ? 9.0 : 10.0;
    final padding = small
        ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
        : const EdgeInsets.symmetric(horizontal: 8, vertical: 3);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(100), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

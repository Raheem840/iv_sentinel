import 'package:flutter/material.dart';
import '../../../core/theme/status_color.dart';

/// Small pill badge showing NORMAL / LOW / CRITICAL with the matching status color.
class StatusBadge extends StatelessWidget {
  final int statusCode;
  final bool small;

  const StatusBadge({super.key, required this.statusCode, this.small = false});

  @override
  Widget build(BuildContext context) {
    final color = statusColor(statusCode);
    final label = statusLabel(statusCode);
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

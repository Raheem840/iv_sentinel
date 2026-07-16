import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Paints a traveling ECG-style pulse line, evoking a hospital heart monitor.
/// Shared between the cold-start splash screen and in-page refresh overlays.
class EcgPulsePainter extends CustomPainter {
  EcgPulsePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final basePaint = Paint()
      ..color = kStatusGreenDim
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final midY = size.height / 2;
    canvas.drawLine(Offset(0, midY), Offset(size.width, midY), basePaint);

    final path = Path();
    final midX = size.width * progress;
    path.moveTo(0, midY);
    final segments = [
      Offset(midX - 24, midY),
      Offset(midX - 16, midY - 14),
      Offset(midX - 8, midY + 18),
      Offset(midX, midY - 22),
      Offset(midX + 8, midY),
    ];
    for (final point in segments) {
      if (point.dx < 0) continue;
      path.lineTo(point.dx.clamp(0, size.width), point.dy);
    }
    path.lineTo(size.width, midY);

    final tracePaint = Paint()
      ..color = kStatusGreen
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, tracePaint);
  }

  @override
  bool shouldRepaint(covariant EcgPulsePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

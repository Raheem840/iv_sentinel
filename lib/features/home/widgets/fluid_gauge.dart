import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/status_color.dart';

/// Circular arc gauge — the visual centerpiece of each bed card.
///
/// Design reference: Oura Ring readiness score, Apple Watch activity rings.
/// A 270° sweep arc represents 0–100% fluid. The track color is dim; the
/// filled arc transitions between status colors (green → amber → red).
class FluidGauge extends StatelessWidget {
  final double percent; // 0–100
  final int statusCode;
  final bool isLoading;
  final double size;

  const FluidGauge({
    super.key,
    required this.percent,
    required this.statusCode,
    this.isLoading = false,
    this.size = 110,
  });

  @override
  Widget build(BuildContext context) {
    final color = statusColor(statusCode);

    // TweenAnimationBuilder smoothly animates the arc fill when percent changes
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: isLoading ? 0 : percent.clamp(0, 100)),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, animatedPercent, _) {
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _GaugePainter(
              percent: animatedPercent,
              color: color,
              trackColor: kBorderDark.withAlpha(100),
              strokeWidth: size * 0.10,
            ),
            child: Center(
              child: isLoading
                  ? SizedBox(
                      width: size * 0.28,
                      height: size * 0.28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: kTextSecondaryDark,
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${animatedPercent.round()}%',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: size * 0.22,
                            fontWeight: FontWeight.w800,
                            color: color,
                            // Tabular figures so digits don't shift width
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        Text(
                          'fluid',
                          style: TextStyle(
                            fontSize: size * 0.09,
                            color: kTextSecondaryDark,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double percent;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  // Arc starts at 7:30 (bottom-left) and sweeps 270° clockwise to 4:30
  static const _startAngle = math.pi * 0.75; // 135° from 3 o'clock = 7:30 position
  static const _totalSweep = math.pi * 1.5;  // 270° total arc

  const _GaugePainter({
    required this.percent,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = trackColor;

    // Draw the background track (full 270° arc)
    canvas.drawArc(rect, _startAngle, _totalSweep, false, trackPaint);

    if (percent <= 0) return;

    final fillSweep = _totalSweep * (percent / 100);

    // Draw a subtle glow behind the filled arc for the premium depth effect
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 4
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
      ..color = color.withAlpha(40);
    canvas.drawArc(rect, _startAngle, fillSweep, false, glowPaint);

    // Draw the filled arc
    final fillPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(rect, _startAngle, fillSweep, false, fillPaint);

    // Draw a bright tip dot at the leading edge of the fill
    final tipAngle = _startAngle + fillSweep;
    final tipX = center.dx + radius * math.cos(tipAngle);
    final tipY = center.dy + radius * math.sin(tipAngle);
    final tipPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(tipX, tipY), strokeWidth * 0.45, tipPaint);
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.percent != percent || old.color != color;
}

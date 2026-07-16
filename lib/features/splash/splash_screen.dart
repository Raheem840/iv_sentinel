import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/services/alert_service.dart';
import '../../core/theme/app_colors.dart';

/// Branded loading screen shown while [AlertService] initializes.
/// Displays "IV SENTINEL" in a monitor/ECG-style font with a pulse-line
/// loading indicator, then hands off to [nextRoute].
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.nextRoute});

  final String nextRoute;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _boot();
  }

  Future<void> _boot() async {
    final minDisplay = Future.delayed(const Duration(milliseconds: 1200));
    final init = AlertService.instance
        .init()
        .timeout(const Duration(seconds: 3), onTimeout: () {});
    await Future.wait([minDisplay, init]);
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(widget.nextRoute);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundDark,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'IV SENTINEL',
              style: GoogleFonts.shareTechMono(
                fontSize: 34,
                color: kStatusGreen,
                letterSpacing: 6,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'PATIENT MONITORING',
              style: GoogleFonts.shareTechMono(
                fontSize: 12,
                color: kTextSecondaryDark,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: 220,
              height: 40,
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, _) => CustomPaint(
                  painter: _PulseLinePainter(progress: _pulseController.value),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Paints a traveling ECG-style pulse line, evoking a hospital heart monitor.
class _PulseLinePainter extends CustomPainter {
  _PulseLinePainter({required this.progress});

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
  bool shouldRepaint(covariant _PulseLinePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

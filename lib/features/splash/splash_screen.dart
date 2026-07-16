import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/services/alert_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/ecg_pulse_painter.dart';

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
    final init = AlertService.instance.init().timeout(
      const Duration(seconds: 3),
      onTimeout: () {},
    );
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
                  painter: EcgPulsePainter(progress: _pulseController.value),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'ecg_pulse_painter.dart';

/// Wraps [child] and shows an ECG-pulse loading scrim on top whenever
/// [isLoading] is true, staying visible for at least [minDuration] so a
/// fast refresh still reads as a deliberate "page refreshed" moment.
class PulseLoadingOverlay extends StatefulWidget {
  const PulseLoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.minDuration = const Duration(milliseconds: 700),
  });

  final bool isLoading;
  final Widget child;
  final Duration minDuration;

  @override
  State<PulseLoadingOverlay> createState() => _PulseLoadingOverlayState();
}

class _PulseLoadingOverlayState extends State<PulseLoadingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late bool _visible = widget.isLoading;
  Timer? _minTimer;
  bool _pendingHide = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    if (_visible) _armMinTimer();
  }

  @override
  void didUpdateWidget(covariant PulseLoadingOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading && !oldWidget.isLoading) {
      setState(() => _visible = true);
      _armMinTimer();
    } else if (!widget.isLoading && oldWidget.isLoading) {
      if (_minTimer?.isActive ?? false) {
        _pendingHide = true;
      } else {
        setState(() => _visible = false);
      }
    }
  }

  void _armMinTimer() {
    _pendingHide = false;
    _minTimer?.cancel();
    _minTimer = Timer(widget.minDuration, () {
      if (mounted && (_pendingHide || !widget.isLoading)) {
        setState(() => _visible = false);
      }
    });
  }

  @override
  void dispose() {
    _minTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_visible)
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: _visible ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                color: kBackgroundDark.withAlpha(235),
                child: Center(
                  child: SizedBox(
                    width: 200,
                    height: 32,
                    child: AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, _) => CustomPaint(
                        painter: EcgPulsePainter(
                          progress: _pulseController.value,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

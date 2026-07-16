import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/models/bed_config.dart';
import '../../../core/models/bed_reading.dart';
import '../../../core/theme/status_color.dart';
import 'fluid_gauge.dart';
import 'sparkline_chart.dart';
import 'status_badge.dart';

/// Premium bed monitoring card with a circular arc gauge as the visual centerpiece.
/// Design reference: Oura Ring readiness card, Apple Health metric cards.
class BedCard extends StatefulWidget {
  final BedConfig config;
  final BedReading? reading;
  final bool hasError;
  final List<double> history;
  final VoidCallback onTap;

  const BedCard({
    super.key,
    required this.config,
    required this.reading,
    this.hasError = false,
    required this.history,
    required this.onTap,
  });

  @override
  State<BedCard> createState() => _BedCardState();
}

class _BedCardState extends State<BedCard> with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseAnim = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
    _updatePulse();
  }

  @override
  void didUpdateWidget(BedCard old) {
    super.didUpdateWidget(old);
    if (old.reading?.statusCode != widget.reading?.statusCode) _updatePulse();
  }

  void _updatePulse() {
    if (widget.reading?.isCritical == true) {
      _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reading = widget.reading;
    final statusCode = reading?.statusCode ?? 0;
    final color = statusColor(statusCode);
    final isCritical = reading?.isCritical ?? false;
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _pulseAnim,
        builder: (context, child) => Container(
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withAlpha(
                isCritical ? (_pulseAnim.value * 220).toInt() : 45,
              ),
              width: isCritical ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: isCritical
                    ? color.withAlpha((_pulseAnim.value * 55).toInt())
                    : Colors.black.withAlpha(35),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: child,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Header: bed name left, status badge right ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.config.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: reading != null
                        ? StatusBadge(
                            key: ValueKey(statusCode),
                            statusCode: statusCode,
                            small: true,
                          )
                        : widget.hasError
                        ? const StatusBadge(
                            key: ValueKey('no-data'),
                            statusCode: 0,
                            small: true,
                            unknown: true,
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // ── Gauge: the visual hero of the card ──
              // Hero tag enables a smooth shared-element transition to the detail screen.
              Expanded(
                child: Center(
                  child: Hero(
                    tag: 'gauge-${widget.config.id}',
                    child: FluidGauge(
                      percent: reading?.percent ?? 0,
                      statusCode: statusCode,
                      isLoading: reading == null && !widget.hasError,
                      hasError: reading == null && widget.hasError,
                      size: 80,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // ── Footer: sparkline left, timestamp right ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 6,
                    child: SizedBox(
                      height: 28,
                      child: widget.history.length > 2
                          ? SparklineChart(
                              readings: widget.history,
                              statusCode: statusCode,
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (reading != null)
                    _TimestampLabel(timestamp: reading.timestamp),
                ],
              ),

              // ── Threshold micro-label ──
              const SizedBox(height: 4),
              Text(
                'L ${widget.config.lowThreshold.toInt()}%  ·  C ${widget.config.critThreshold.toInt()}%',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 9,
                  letterSpacing: 0.3,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Relative timestamp that refreshes on a Timer (properly cancellable).
class _TimestampLabel extends StatefulWidget {
  final DateTime timestamp;
  const _TimestampLabel({required this.timestamp});

  @override
  State<_TimestampLabel> createState() => _TimestampLabelState();
}

class _TimestampLabelState extends State<_TimestampLabel> {
  late String _label;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _label = _format();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) setState(() => _label = _format());
    });
  }

  @override
  void dispose() {
    _timer?.cancel(); // properly cancellable — no Future.doWhile leak
    super.dispose();
  }

  String _format() {
    final diff = DateTime.now().toUtc().difference(widget.timestamp.toUtc());
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  @override
  Widget build(BuildContext context) => Text(
    _label,
    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 9),
    textAlign: TextAlign.right,
  );
}

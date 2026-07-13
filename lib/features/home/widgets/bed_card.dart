import 'package:flutter/material.dart';
import '../../../core/models/bed_config.dart';
import '../../../core/models/bed_reading.dart';
import '../../../core/theme/status_color.dart';
import 'sparkline_chart.dart';
import 'status_badge.dart';

/// A single bed monitoring card shown in the home grid.
/// Pulses its border when the bed is in CRITICAL status.
class BedCard extends StatefulWidget {
  final BedConfig config;
  final BedReading? reading; // null while first fetch is loading
  final List<double> history; // recent % readings for sparkline
  final VoidCallback onTap;

  const BedCard({
    super.key,
    required this.config,
    required this.reading,
    required this.history,
    required this.onTap,
  });

  @override
  State<BedCard> createState() => _BedCardState();
}

class _BedCardState extends State<BedCard> with SingleTickerProviderStateMixin {
  // Animation controller for the CRITICAL border pulse
  late AnimationController _pulse;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseAnim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
    _updatePulse();
  }

  @override
  void didUpdateWidget(BedCard old) {
    super.didUpdateWidget(old);
    // Re-evaluate pulse whenever status changes
    if (old.reading?.statusCode != widget.reading?.statusCode) {
      _updatePulse();
    }
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
    final isCritical = reading?.isCritical ?? false;
    final statusCode = reading?.statusCode ?? 0;
    final color = statusColor(statusCode);
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _pulseAnim,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                // Border glows status color; pulses opacity if CRITICAL
                color: color.withAlpha(
                  isCritical ? ((_pulseAnim.value) * 200).toInt() : 60,
                ),
                width: isCritical ? 1.5 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: isCritical
                      ? color.withAlpha((_pulseAnim.value * 60).toInt())
                      : Colors.black.withAlpha(40),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: child,
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header row: bed name + status badge ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.config.name,
                      style: theme.textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (reading != null) StatusBadge(statusCode: statusCode),
                ],
              ),

              const SizedBox(height: 8),

              // ── Big % numeral ──
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  reading != null ? '${reading.percent.toInt()}%' : '—',
                  key: ValueKey(reading?.percent.toInt()),
                  style: theme.textTheme.displayMedium?.copyWith(color: color),
                ),
              ),

              const Spacer(),

              // ── Bottom row: sparkline + timestamp ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Sparkline takes 55% of card width
                  Expanded(
                    flex: 55,
                    child: SizedBox(
                      height: 36,
                      child: widget.history.length > 1
                          ? SparklineChart(
                              readings: widget.history,
                              statusCode: statusCode,
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Timestamp
                  Expanded(
                    flex: 45,
                    child: reading != null
                        ? _TimestampLabel(timestamp: reading.timestamp)
                        : const SizedBox.shrink(),
                  ),
                ],
              ),

              // ── Thresholds hint ──
              const SizedBox(height: 4),
              Text(
                'L ${widget.config.lowThreshold.toInt()}% · C ${widget.config.critThreshold.toInt()}%',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows how long ago the last reading arrived, updating every second.
class _TimestampLabel extends StatefulWidget {
  final DateTime timestamp;
  const _TimestampLabel({required this.timestamp});

  @override
  State<_TimestampLabel> createState() => _TimestampLabelState();
}

class _TimestampLabelState extends State<_TimestampLabel> {
  late String _label;

  @override
  void initState() {
    super.initState();
    _label = _format();
    // Refresh label every 10 seconds
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 10));
      if (!mounted) return false;
      setState(() => _label = _format());
      return true;
    });
  }

  String _format() {
    final diff = DateTime.now().toUtc().difference(widget.timestamp.toUtc());
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _label,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10),
      textAlign: TextAlign.right,
    );
  }
}

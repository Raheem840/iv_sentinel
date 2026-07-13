import 'package:flutter/material.dart';
import '../../../core/models/bed_config.dart';
import '../../../core/models/bed_reading.dart';
import '../../../core/theme/app_colors.dart';

/// Sticky alert banner that appears above the grid when ≥1 bed is CRITICAL.
/// Tapping navigates directly to that bed's detail screen.
class CriticalBanner extends StatefulWidget {
  final List<BedConfig> criticalBeds;
  final Map<String, BedReading> readings;
  final void Function(BedConfig) onTap;

  const CriticalBanner({
    super.key,
    required this.criticalBeds,
    required this.readings,
    required this.onTap,
  });

  @override
  State<CriticalBanner> createState() => _CriticalBannerState();
}

class _CriticalBannerState extends State<CriticalBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.criticalBeds.length;
    if (count == 0) return const SizedBox.shrink();

    final names = widget.criticalBeds.map((b) => b.name).join(', ');
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, child) => GestureDetector(
        onTap: () => widget.onTap(widget.criticalBeds.first),
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: kStatusRed.withAlpha(
              (30 + (_pulse.value * 20)).toInt(),
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: kStatusRed.withAlpha(
                (120 + (_pulse.value * 80).toInt()),
              ),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              // Pulsing dot indicator
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kStatusRed.withAlpha(
                    (180 + (_pulse.value * 75).toInt()),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      count == 1
                          ? 'CRITICAL — $names'
                          : '$count beds CRITICAL',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: kStatusRed,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (count == 1)
                      Text(
                        '${widget.readings[widget.criticalBeds.first.id]?.percent.toInt() ?? '—'}% fluid remaining. Tap to view.',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: kStatusRed.withAlpha(180)),
                      )
                    else
                      Text(
                        names,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: kStatusRed.withAlpha(180)),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: kStatusRed, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

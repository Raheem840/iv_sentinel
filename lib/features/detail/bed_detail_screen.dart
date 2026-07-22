import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/models/bed_config.dart';
import '../../core/models/bed_reading.dart';
import '../../core/providers/bed_history_provider.dart';
import '../../core/providers/bed_readings_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/status_color.dart';
import '../../core/widgets/pulse_loading_overlay.dart';
import '../home/widgets/fluid_gauge.dart';
import '../home/widgets/status_badge.dart';
import 'widgets/history_chart.dart';

class BedDetailScreen extends ConsumerWidget {
  final BedConfig config;

  const BedDetailScreen({super.key, required this.config});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The history chart is fetched once (feeds.json) and doesn't ride the
    // live-reading poll, so it can go stale — e.g. a bed added before it had
    // any published readings keeps showing an empty chart forever even after
    // real data starts arriving. Re-fetch history whenever a genuinely new
    // reading timestamp lands for this bed while its detail screen is open.
    ref.listen<AsyncValue<Map<String, BedReading>>>(bedReadingsProvider, (
      previous,
      next,
    ) {
      final prevTimestamp = previous?.valueOrNull?[config.id]?.timestamp;
      final nextTimestamp = next.valueOrNull?[config.id]?.timestamp;
      if (nextTimestamp != null && nextTimestamp != prevTimestamp) {
        ref.invalidate(bedHistoryProvider(config));
      }
    });

    final historyAsync = ref.watch(bedHistoryProvider(config));
    final readingsAsyncValue = ref.watch(bedReadingsProvider);
    final liveReading = readingsAsyncValue.whenData((m) => m[config.id]).value;
    final hasNoData =
        liveReading == null &&
        (readingsAsyncValue.hasError ||
            ref.read(bedReadingsProvider.notifier).hasError(config.id));

    final statusCode = liveReading?.statusCode ?? 0;
    final color = hasNoData ? kTextSecondaryDark : statusColor(statusCode);
    final percent = liveReading?.percent ?? 0;

    // Compute simple trend from history (last reading vs reading 10 steps ago)
    final historyData = historyAsync.valueOrNull;
    final trend = _computeTrend(historyData);

    return Scaffold(
      // Transparent AppBar so gradient bleeds to top
      backgroundColor: kBackgroundDark,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: kTextPrimaryDark),
        title: Text(
          config.name,
          style: const TextStyle(
            color: kTextPrimaryDark,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: kTextPrimaryDark),
            tooltip: 'Refresh history',
            onPressed: () => ref.invalidate(bedHistoryProvider(config)),
          ),
        ],
      ),
      body: PulseLoadingOverlay(
        isLoading: historyAsync.isLoading,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // ── Gradient hero header ──
            _GradientHeader(
              config: config,
              percent: percent,
              statusCode: statusCode,
              color: color,
              timestamp: liveReading?.timestamp,
              trend: trend,
              hasNoData: hasNoData,
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Threshold chips ──
                  Row(
                    children: [
                      _ThresholdChip(
                        label: 'LOW alert',
                        value: '${config.lowThreshold.toInt()}%',
                        color: kStatusAmber,
                      ),
                      const SizedBox(width: 12),
                      _ThresholdChip(
                        label: 'CRITICAL alert',
                        value: '${config.critThreshold.toInt()}%',
                        color: kStatusRed,
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // ── History section header ──
                  Row(
                    children: [
                      const Text(
                        'History',
                        style: TextStyle(
                          color: kTextPrimaryDark,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'last 60 readings',
                        style: TextStyle(
                          color: kTextSecondaryDark,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── History chart ──
                  SizedBox(
                    height: 260,
                    child: historyAsync.when(
                      loading: () => const Center(
                        child: CircularProgressIndicator(color: kStatusGreen),
                      ),
                      error: (e, _) => _ChartError(
                        message: e.toString(),
                        onRetry: () =>
                            ref.invalidate(bedHistoryProvider(config)),
                      ),
                      data: (readings) => readings.isEmpty
                          ? _EmptyHistory(
                              onRetry: () =>
                                  ref.invalidate(bedHistoryProvider(config)),
                            )
                          : HistoryChart(
                              readings: readings,
                              lowThreshold: config.lowThreshold,
                              critThreshold: config.critThreshold,
                            ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Channel info section ──
                  const Text(
                    'Channel Info',
                    style: TextStyle(
                      color: kTextPrimaryDark,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),

                  _InfoCard(
                    children: [
                      _InfoRow(label: 'Channel ID', value: config.channelId),
                      _InfoRow(
                        label: 'API Key',
                        value: config.apiKey.length >= 4
                            ? '${config.apiKey.substring(0, 4)}••••••••'
                            : '••••••••',
                      ),
                      _InfoRow(label: 'Poll interval', value: 'auto'),
                    ],
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Compare last reading to one 10 steps earlier to estimate direction.
  double? _computeTrend(List<BedReading>? history) {
    if (history == null || history.length < 10) return null;
    return history.last.percent - history[history.length - 10].percent;
  }
}

// ── Gradient hero header ──────────────────────────────────────────────────────

class _GradientHeader extends StatelessWidget {
  final BedConfig config;
  final double percent;
  final int statusCode;
  final Color color;
  final DateTime? timestamp;
  final double? trend;
  final bool hasNoData;

  const _GradientHeader({
    required this.config,
    required this.percent,
    required this.statusCode,
    required this.color,
    required this.timestamp,
    required this.trend,
    required this.hasNoData,
  });

  @override
  Widget build(BuildContext context) {
    final timeFmt = DateFormat('MMM d, HH:mm');
    final topPad = MediaQuery.of(context).padding.top + kToolbarHeight;

    return Container(
      padding: EdgeInsets.fromLTRB(24, topPad + 16, 24, 32),
      decoration: BoxDecoration(
        // Gradient from subtle status-color tint at top to surface at bottom
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withAlpha(28), kSurfaceDark.withAlpha(255)],
          stops: const [0.0, 1.0],
        ),
        border: Border(bottom: BorderSide(color: kBorderDark, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Hero gauge — shared element with BedCard
          Hero(
            tag: 'gauge-${config.id}',
            child: FluidGauge(
              percent: percent,
              statusCode: statusCode,
              hasError: hasNoData,
              size: 140,
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatusBadge(statusCode: statusCode, unknown: hasNoData),
                const SizedBox(height: 12),

                if (hasNoData)
                  Text(
                    'No connection to this bed\'s sensor yet.',
                    style: TextStyle(color: kTextSecondaryDark, fontSize: 12),
                  )
                else ...[
                  // Trend indicator
                  if (trend != null) _TrendRow(trend: trend!),
                  if (trend != null) const SizedBox(height: 10),

                  // Updated timestamp
                  if (timestamp != null) ...[
                    Text(
                      'Updated',
                      style: TextStyle(color: kTextSecondaryDark, fontSize: 11),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      timeFmt.format(timestamp!.toLocal()),
                      style: const TextStyle(
                        color: kTextPrimaryDark,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Trend indicator ───────────────────────────────────────────────────────────

class _TrendRow extends StatelessWidget {
  final double trend;
  const _TrendRow({required this.trend});

  @override
  Widget build(BuildContext context) {
    final isRising = trend > 0.5;
    final isFalling = trend < -0.5;
    final color = isFalling ? kStatusAmber : kStatusGreen;
    final icon = isRising
        ? Icons.trending_up_rounded
        : isFalling
        ? Icons.trending_down_rounded
        : Icons.trending_flat_rounded;
    final label = trend > 0
        ? '+${trend.abs().toStringAsFixed(1)}% (10 readings)'
        : '${trend.toStringAsFixed(1)}% (10 readings)';

    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ── Threshold chips ───────────────────────────────────────────────────────────

class _ThresholdChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ThresholdChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withAlpha(18),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(55)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Grouped info card ─────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kSurfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderDark),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1) Divider(height: 1, color: kBorderDark),
          ],
        ],
      ),
    );
  }
}

// ── Info row ──────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: kTextSecondaryDark, fontSize: 13),
          ),
          Text(
            value,
            style: const TextStyle(
              color: kTextPrimaryDark,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Chart empty state ─────────────────────────────────────────────────────────
//
// A bed added while its channel had no (or too little) published data yet
// caches an empty history result. Auto-retry once shortly after this state
// appears so the chart self-heals as soon as feeds.json catches up, and
// offer a manual Retry for anyone who doesn't want to wait.
class _EmptyHistory extends StatefulWidget {
  final VoidCallback onRetry;

  const _EmptyHistory({required this.onRetry});

  @override
  State<_EmptyHistory> createState() => _EmptyHistoryState();
}

class _EmptyHistoryState extends State<_EmptyHistory> {
  Timer? _autoRetryTimer;

  @override
  void initState() {
    super.initState();
    _autoRetryTimer = Timer(const Duration(seconds: 5), widget.onRetry);
  }

  @override
  void dispose() {
    _autoRetryTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'No history available yet',
            style: TextStyle(color: kTextSecondaryDark),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: widget.onRetry,
            child: const Text('Retry', style: TextStyle(color: kStatusGreen)),
          ),
        ],
      ),
    );
  }
}

// ── Chart error state ─────────────────────────────────────────────────────────

class _ChartError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ChartError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline, color: kStatusAmber, size: 36),
        const SizedBox(height: 8),
        Text(
          'Failed to load history',
          style: const TextStyle(color: kTextPrimaryDark, fontSize: 14),
        ),
        TextButton(
          onPressed: onRetry,
          child: const Text('Retry', style: TextStyle(color: kStatusGreen)),
        ),
      ],
    );
  }
}

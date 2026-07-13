import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/models/bed_config.dart';
import '../../core/providers/bed_history_provider.dart';
import '../../core/providers/bed_readings_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/status_color.dart';
import '../home/widgets/status_badge.dart';
import 'widgets/history_chart.dart';

class BedDetailScreen extends ConsumerWidget {
  final BedConfig config;

  const BedDetailScreen({super.key, required this.config});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(bedHistoryProvider(config));
    // Also watch live readings to keep the header current % up-to-date
    final liveReading = ref
        .watch(bedReadingsProvider)
        .whenData((m) => m[config.id])
        .value;

    final theme = Theme.of(context);
    final statusCode = liveReading?.statusCode ?? 0;
    final color = statusColor(statusCode);
    final timeFmt = DateFormat('MMM d, HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: Text(config.name),
        actions: [
          // Manual refresh — invalidates the history provider, triggering a refetch
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh history',
            onPressed: () => ref.invalidate(bedHistoryProvider(config)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Live reading header card ──
          _HeaderCard(
            percent: liveReading?.percent,
            statusCode: statusCode,
            color: color,
            timestamp: liveReading?.timestamp,
            timeFmt: timeFmt,
            theme: theme,
          ),

          const SizedBox(height: 24),

          // ── Thresholds info row ──
          Row(
            children: [
              _ThresholdChip(
                label: 'LOW threshold',
                value: '${config.lowThreshold.toInt()}%',
                color: kStatusAmber,
              ),
              const SizedBox(width: 12),
              _ThresholdChip(
                label: 'CRITICAL threshold',
                value: '${config.critThreshold.toInt()}%',
                color: kStatusRed,
              ),
            ],
          ),

          const SizedBox(height: 24),

          Text('History (last 60 readings)', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('Channel ${config.channelId}', style: theme.textTheme.bodySmall),
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
                onRetry: () => ref.invalidate(bedHistoryProvider(config)),
              ),
              data: (readings) => readings.isEmpty
                  ? Center(
                      child: Text(
                        'No history available yet',
                        style: theme.textTheme.bodySmall,
                      ),
                    )
                  : HistoryChart(
                      readings: readings,
                      lowThreshold: config.lowThreshold,
                      critThreshold: config.critThreshold,
                    ),
            ),
          ),

          const SizedBox(height: 24),

          // ── Channel info ──
          _InfoRow(label: 'Channel ID', value: config.channelId),
          _InfoRow(label: 'API Key', value: '${config.apiKey.substring(0, 4)}••••••••'),
        ],
      ),
    );
  }
}

// ── Header card with the current live reading ─────────────────────────────────

class _HeaderCard extends StatelessWidget {
  final double? percent;
  final int statusCode;
  final Color color;
  final DateTime? timestamp;
  final DateFormat timeFmt;
  final ThemeData theme;

  const _HeaderCard({
    required this.percent,
    required this.statusCode,
    required this.color,
    required this.timestamp,
    required this.timeFmt,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(80), width: 1.5),
      ),
      child: Row(
        children: [
          // Big % reading
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              percent != null ? '${percent!.toInt()}%' : '—',
              key: ValueKey(percent?.toInt()),
              style: theme.textTheme.displayLarge?.copyWith(color: color),
            ),
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StatusBadge(statusCode: statusCode),
              const SizedBox(height: 8),
              if (timestamp != null)
                Text(
                  'Updated ${timeFmt.format(timestamp!.toLocal())}',
                  style: theme.textTheme.bodySmall,
                ),
              const SizedBox(height: 4),
              Text('Fluid level', style: theme.textTheme.bodySmall),
            ],
          ),
        ],
      ),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w700)),
          ],
        ),
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
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          Text(value, style: theme.textTheme.bodyMedium),
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
        Text('Failed to load history', style: Theme.of(context).textTheme.bodyMedium),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}

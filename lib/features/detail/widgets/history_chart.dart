import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/models/bed_reading.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/status_color.dart';

/// Full-size line chart showing the last 60 readings with threshold reference lines.
class HistoryChart extends StatelessWidget {
  final List<BedReading> readings;
  final double lowThreshold;
  final double critThreshold;

  const HistoryChart({
    super.key,
    required this.readings,
    required this.lowThreshold,
    required this.critThreshold,
  });

  @override
  Widget build(BuildContext context) {
    if (readings.isEmpty) {
      return const Center(child: Text('No history data'));
    }

    final theme = Theme.of(context);

    // Build chart spots — one per reading
    final spots = [
      for (var i = 0; i < readings.length; i++)
        FlSpot(i.toDouble(), readings[i].percent),
    ];

    // Color the line by current (last) status
    final lineColor = statusColor(readings.last.statusCode);

    // X-axis labels: show time for ~5 evenly-spaced points
    final labelStep = (readings.length / 5).ceil();
    final timeFmt = DateFormat('HH:mm');

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 100,
        clipData: const FlClipData.all(),

        // ── Grid ──
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 25,
          getDrawingHorizontalLine: (_) => FlLine(
            color: theme.dividerColor.withAlpha(60),
            strokeWidth: 1,
          ),
        ),

        // ── Axes ──
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              interval: 25,
              getTitlesWidget: (value, _) => Text(
                '${value.toInt()}%',
                style: TextStyle(
                  color: kTextSecondaryDark,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: labelStep.toDouble(),
              getTitlesWidget: (value, _) {
                final idx = value.toInt();
                if (idx < 0 || idx >= readings.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    timeFmt.format(readings[idx].timestamp.toLocal()),
                    style: TextStyle(color: kTextSecondaryDark, fontSize: 10),
                  ),
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),

        borderData: FlBorderData(show: false),

        // ── Threshold reference lines (dashed) ──
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: lowThreshold,
              color: kStatusAmber.withAlpha(180),
              strokeWidth: 1.5,
              dashArray: [6, 4],
              label: HorizontalLineLabel(
                show: true,
                alignment: Alignment.topRight,
                labelResolver: (_) => 'LOW',
                style: TextStyle(color: kStatusAmber, fontSize: 10, fontWeight: FontWeight.w600),
              ),
            ),
            HorizontalLine(
              y: critThreshold,
              color: kStatusRed.withAlpha(180),
              strokeWidth: 1.5,
              dashArray: [6, 4],
              label: HorizontalLineLabel(
                show: true,
                alignment: Alignment.topRight,
                labelResolver: (_) => 'CRIT',
                style: TextStyle(color: kStatusRed, fontSize: 10, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),

        // ── Data line ──
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.25,
            color: lineColor,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [lineColor.withAlpha(50), lineColor.withAlpha(0)],
              ),
            ),
          ),
        ],

        // ── Touch tooltip ──
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => theme.cardTheme.color ?? kSurfaceDark,
            tooltipRoundedRadius: 8,
            getTooltipItems: (touchedSpots) => touchedSpots
                .map((s) => LineTooltipItem(
                      '${s.y.toInt()}%\n${timeFmt.format(readings[s.x.toInt()].timestamp.toLocal())}',
                      TextStyle(color: lineColor, fontSize: 12, fontWeight: FontWeight.w600),
                    ))
                .toList(),
          ),
        ),
      ),
      duration: const Duration(milliseconds: 300),
    );
  }
}

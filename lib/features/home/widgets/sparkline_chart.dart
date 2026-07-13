import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/status_color.dart';

/// Minimal sparkline — no axes, no labels, just the trend line + colored fill.
/// Displays the last [readings] data points.
class SparklineChart extends StatelessWidget {
  final List<double> readings; // percent values in chronological order
  final int statusCode;

  const SparklineChart({
    super.key,
    required this.readings,
    required this.statusCode,
  });

  @override
  Widget build(BuildContext context) {
    if (readings.isEmpty) return const SizedBox.shrink();

    final color = statusColor(statusCode);

    // Convert the list of doubles into fl_chart FlSpots (x = index, y = value)
    final spots = [
      for (var i = 0; i < readings.length; i++)
        FlSpot(i.toDouble(), readings[i]),
    ];

    return LineChart(
      LineChartData(
        // Remove all grid lines and axis labels — pure sparkline look
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        minY: 0,
        maxY: 100,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.35,
            color: color,
            barWidth: 1.5,
            dotData: const FlDotData(show: false),
            // Colored fill under the line
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [color.withAlpha(60), color.withAlpha(0)],
              ),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 300),
    );
  }
}

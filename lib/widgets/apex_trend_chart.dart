import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';

class ApexTrendChart extends StatelessWidget {
  final List<double> values;
  final List<String>? labels;
  final Color color;
  final double height;
  final bool compact;

  const ApexTrendChart({
    super.key,
    required this.values,
    this.labels,
    required this.color,
    this.height = 148,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final safeValues = values.isEmpty ? const [0.0] : values;
    final maxVal = safeValues.fold<double>(1, (a, b) => b > a ? b : a);
    final maxY = maxVal <= 0 ? 1.0 : maxVal * 1.18;

    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceBetween,
          maxY: maxY,
          minY: 0,
          gridData: FlGridData(
            show: !compact,
            drawVerticalLine: false,
            horizontalInterval: maxY / 3,
            getDrawingHorizontalLine: (value) => FlLine(
              color: ApexColors.border,
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: labels != null,
                reservedSize: compact ? 20 : 24,
                getTitlesWidget: (value, meta) {
                  if (labels == null) {
                    return const SizedBox.shrink();
                  }
                  final index = value.toInt();
                  if (index < 0 || index >= labels!.length) {
                    return const SizedBox.shrink();
                  }
                  final label = labels![index];
                  if (label.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return SideTitleWidget(
                    meta: meta,
                    space: 8,
                    child: Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: compact ? 9 : 10,
                        color: ApexColors.t3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(enabled: false),
          barGroups: List.generate(safeValues.length, (index) {
            final value = safeValues[index];
            return BarChartGroupData(
              x: index,
              barsSpace: 0,
              barRods: [
                BarChartRodData(
                  toY: value,
                  width: compact ? 12 : 18,
                  borderRadius: BorderRadius.circular(999),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      color,
                      color.withAlpha(132),
                    ],
                  ),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: maxY,
                    color: ApexColors.cardAlt.withAlpha(210),
                  ),
                ),
              ],
            );
          }),
        ),
        duration: const Duration(milliseconds: 720),
        curve: Curves.easeOutCubic,
      ),
    );
  }
}

class ApexLineTrendChart extends StatelessWidget {
  final List<double> values;
  final Color color;
  final double height;

  const ApexLineTrendChart({
    super.key,
    required this.values,
    required this.color,
    this.height = 92,
  });

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) {
      return SizedBox(height: height);
    }

    final maxVal = values.fold<double>(values.first, (a, b) => b > a ? b : a);
    final minVal = values.fold<double>(values.first, (a, b) => b < a ? b : a);
    final range = (maxVal - minVal).abs() < 0.25 ? 0.25 : (maxVal - minVal);

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minY: minVal - range * 0.15,
          maxY: maxVal + range * 0.15,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: range / 3,
            getDrawingHorizontalLine: (value) => FlLine(
              color: ApexColors.border,
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: const FlTitlesData(
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          lineTouchData: LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              isCurved: true,
              curveSmoothness: 0.35,
              color: color,
              barWidth: 4.5,
              spots: List.generate(
                values.length,
                (index) => FlSpot(index.toDouble(), values[index]),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [color.withAlpha(80), Colors.transparent],
                ),
              ),
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                  radius: 3.4,
                  color: color,
                  strokeWidth: 1.5,
                  strokeColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(milliseconds: 720),
        curve: Curves.easeOutCubic,
      ),
    );
  }
}

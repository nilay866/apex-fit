import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';

class GoalCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final double current;
  final double goal;
  final String unit;
  final Color color;
  final VoidCallback? onTap;
  final String? overrideStatusText;

  const GoalCard({
    super.key,
    required this.icon,
    required this.label,
    required this.current,
    required this.goal,
    required this.unit,
    required this.color,
    this.onTap,
    this.overrideStatusText,
  });

  @override
  Widget build(BuildContext context) {
    final pct = goal > 0 ? (current / goal).clamp(0.0, 1.0) : 0.0;
    final pctInt = (pct * 100).round();
    final remaining = (goal - current).clamp(0.0, goal);

    // Format values (show decimals only for water)
    String fmt(double v) {
      if (v == v.roundToDouble()) return v.round().toString();
      return v.toStringAsFixed(1);
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ApexColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withAlpha(30)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(icon, color: color, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: ApexColors.t3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Icon(
                  Icons.edit_rounded,
                  size: 12,
                  color: ApexColors.t3.withAlpha(120),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Progress ring + value
            Center(
              child: SizedBox(
                width: 64,
                height: 64,
                child: CustomPaint(
                  painter: _GoalRingPainter(
                    progress: pct,
                    color: color,
                  ),
                  child: Center(
                    child: Text(
                      '$pctInt%',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Current / Goal
            Center(
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: fmt(current),
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: ApexColors.t1,
                      ),
                    ),
                    TextSpan(
                      text: ' / ${fmt(goal)}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: ApexColors.t3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 2),
            Center(
              child: Text(
                unit,
                style: GoogleFonts.inter(
                  fontSize: 9,
                  color: ApexColors.t3,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),

            const SizedBox(height: 6),

            // Smart insight
            Center(
              child: Text(
                overrideStatusText ??
                    (pct >= 1.0
                        ? '✓ Goal reached!'
                        : '${fmt(remaining)} $unit left'),
                style: GoogleFonts.inter(
                  fontSize: 9,
                  color: (overrideStatusText == 'Good Recovery' || pct >= 1.0)
                      ? ApexColors.green
                      : color.withAlpha(180),
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalRingPainter extends CustomPainter {
  final double progress;
  final Color color;

  const _GoalRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 4;
    const strokeWidth = 6.0;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Background track
    paint.color = color.withAlpha(25);
    canvas.drawCircle(center, radius, paint);

    // Progress arc
    paint.color = color;
    final sweep = 2 * math.pi * progress.clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_GoalRingPainter old) =>
      old.progress != progress || old.color != color;
}

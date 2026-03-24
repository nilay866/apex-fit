import 'dart:math';
import 'package:flutter/material.dart';
import 'package:apex_ai/constants/colors.dart';
import 'package:apex_ai/services/nfi_service.dart';
import 'package:google_fonts/google_fonts.dart';

class NfiRingWidget extends StatelessWidget {
  final NfiResult? result;
  final bool isLoading;

  const NfiRingWidget({
    super.key,
    required this.result,
    this.isLoading = false,
  });

  Color get _ringColor {
    final s = result?.score ?? 50;
    if (s >= 80) return ApexColors.green;
    if (s >= 50) return ApexColors.nfiAmber;
    return ApexColors.nfiRed;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Container(
        height: 110,
        decoration: BoxDecoration(
          color: ApexColors.cardAlt,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ApexColors.borderStrong),
        ),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final score = result?.score ?? 0;
    final pct = score / 100.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ApexColors.cardAlt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _ringColor.withAlpha(60)),
      ),
      child: Row(
        children: [
          // Ring
          SizedBox(
            width: 72,
            height: 72,
            child: CustomPaint(
              painter: _RingPainter(pct: pct, color: _ringColor),
              child: Center(
                child: Text(
                  '$score',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _ringColor,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Neural Fatigue Index',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: ApexColors.t3,
                    letterSpacing: 0.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  result?.label ?? '—',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _ringColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  result?.recommendation ?? 'Gathering health data...',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: ApexColors.t2,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double pct;
  final Color color;
  const _RingPainter({required this.pct, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = size.width / 2 - 6;
    const stroke = 6.0;

    // Track
    final trackPaint = Paint()
      ..color = color.withAlpha(30)
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset(cx, cy), radius, trackPaint);

    // Fill
    final fillPaint = Paint()
      ..color = color
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius),
      -pi / 2,
      2 * pi * pct,
      false,
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.pct != pct;
}

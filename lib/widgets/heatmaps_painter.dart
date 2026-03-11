import 'package:flutter/material.dart';
import '../constants/colors.dart';

class AnatomyHeatmapPainter extends CustomPainter {
  final Map<String, double> intensity; // 0.0 to 1.0 per muscle

  AnatomyHeatmapPainter({required this.intensity});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = ApexColors.borderStrong
      ..strokeWidth = 2;

    void drawPart(String id, Path path) {
      final val = intensity[id] ?? 0.0;
      paint.color = Color.lerp(ApexColors.surface, ApexColors.red, val)!;
      canvas.drawPath(path, paint);
      canvas.drawPath(path, strokePaint);
    }

    final double w = size.width;
    final double h = size.height;
    
    // Highly stylized geometric body mapping
    
    // Head (Traps/Neck ignored for simplicity, or we can just map it)
    final head = Path()..addOval(Rect.fromCenter(center: Offset(w*0.5, h*0.1), width: w*0.2, height: h*0.15));
    drawPart('Head', head);

    // Shoulders
    final lShoulder = Path()..addOval(Rect.fromCenter(center: Offset(w*0.3, h*0.25), width: w*0.18, height: h*0.15));
    final rShoulder = Path()..addOval(Rect.fromCenter(center: Offset(w*0.7, h*0.25), width: w*0.18, height: h*0.15));
    drawPart('Shoulders', lShoulder);
    drawPart('Shoulders', rShoulder);

    // Chest
    final chest = Path()..addRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(w*0.5, h*0.32), width: w*0.35, height: h*0.15), const Radius.circular(8)));
    drawPart('Chest', chest);

    // Core / Abs
    final core = Path()..addRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(w*0.5, h*0.5), width: w*0.28, height: h*0.18), const Radius.circular(8)));
    drawPart('Core', core);

    // Arms
    final lArm = Path()..addRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(w*0.2, h*0.45), width: w*0.12, height: h*0.25), const Radius.circular(12)));
    final rArm = Path()..addRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(w*0.8, h*0.45), width: w*0.12, height: h*0.25), const Radius.circular(12)));
    drawPart('Arms', lArm);
    drawPart('Arms', rArm);

    // Legs
    final lLeg = Path()..addRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(w*0.38, h*0.75), width: w*0.16, height: h*0.35), const Radius.circular(12)));
    final rLeg = Path()..addRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(w*0.62, h*0.75), width: w*0.16, height: h*0.35), const Radius.circular(12)));
    drawPart('Legs', lLeg);
    drawPart('Legs', rLeg);
  }

  @override
  bool shouldRepaint(covariant AnatomyHeatmapPainter oldDelegate) {
    return oldDelegate.intensity != intensity;
  }
}

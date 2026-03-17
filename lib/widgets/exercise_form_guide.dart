import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../constants/colors.dart';

class ExerciseFormGuide extends StatefulWidget {
  final String motionKey;
  final String title;

  const ExerciseFormGuide({
    super.key,
    required this.motionKey,
    required this.title,
  });

  @override
  State<ExerciseFormGuide> createState() => _ExerciseFormGuideState();
}

class _ExerciseFormGuideState extends State<ExerciseFormGuide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF12171D), Color(0xFF0C1016)],
            ),
            border: Border.all(color: Colors.white10),
            boxShadow: [
              BoxShadow(
                color: ApexColors.accent.withAlpha(25),
                blurRadius: 30,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              const _GuideBackdrop(),
              CustomPaint(
                painter: _ExerciseMotionPainter(
                  progress: Curves.easeInOut.transform(_controller.value),
                  motionKey: widget.motionKey,
                ),
              ),
              Positioned(
                top: 14,
                left: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: ApexColors.accent.withAlpha(28),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: ApexColors.accent.withAlpha(70)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.motion_photos_on_rounded,
                        size: 14,
                        color: ApexColors.accent,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Animated Form Guide',
                        style: TextStyle(
                          color: ApexColors.accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 16,
                left: 18,
                right: 18,
                child: Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GuideBackdrop extends StatelessWidget {
  const _GuideBackdrop();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _GuideBackdropPainter());
  }
}

class _GuideBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withAlpha(16)
      ..strokeWidth = 1;
    final floorPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0x0026C6DA), Color(0x3326C6DA), Color(0x0026C6DA)],
      ).createShader(Rect.fromLTWH(0, size.height - 50, size.width, 18));

    for (double x = 24; x < size.width; x += 32) {
      canvas.drawLine(Offset(x, 36), Offset(x, size.height - 28), gridPaint);
    }
    for (double y = 48; y < size.height - 36; y += 28) {
      canvas.drawLine(Offset(18, y), Offset(size.width - 18, y), gridPaint);
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(18, size.height - 54, size.width - 36, 16),
        const Radius.circular(999),
      ),
      floorPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ExerciseMotionPainter extends CustomPainter {
  final double progress;
  final String motionKey;

  _ExerciseMotionPainter({required this.progress, required this.motionKey});

  @override
  void paint(Canvas canvas, Size size) {
    final accent = Paint()
      ..color = ApexColors.accent
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final accentSoft = Paint()
      ..color = ApexColors.blue
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final guide = Paint()
      ..color = Colors.white24
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final jointPaint = Paint()..color = Colors.white;
    final headPaint = Paint()..color = const Color(0xFFEFF7FF);

    void skeleton({
      required Offset head,
      required Offset shoulder,
      required Offset hip,
      required Offset leftHand,
      required Offset rightHand,
      required Offset leftKnee,
      required Offset rightKnee,
      required Offset leftFoot,
      required Offset rightFoot,
      Paint? limbPaint,
    }) {
      final p = limbPaint ?? accent;
      canvas.drawLine(shoulder, hip, p);
      canvas.drawLine(shoulder, leftHand, p);
      canvas.drawLine(shoulder, rightHand, p);
      canvas.drawLine(hip, leftKnee, p);
      canvas.drawLine(hip, rightKnee, p);
      canvas.drawLine(leftKnee, leftFoot, p);
      canvas.drawLine(rightKnee, rightFoot, p);
      canvas.drawCircle(head, 14, headPaint);
      canvas.drawCircle(head, 14, guide);

      for (final joint in [
        shoulder,
        hip,
        leftHand,
        rightHand,
        leftKnee,
        rightKnee,
        leftFoot,
        rightFoot,
      ]) {
        canvas.drawCircle(joint, 4.5, jointPaint);
      }
    }

    Offset lerpOffset(Offset a, Offset b, double t) {
      return Offset(a.dx + (b.dx - a.dx) * t, a.dy + (b.dy - a.dy) * t);
    }

    final t = progress;
    final width = size.width;
    final height = size.height;
    final centerX = width / 2;
    final groundY = height - 56;

    switch (motionKey) {
      case 'push':
        final shoulder = lerpOffset(
          Offset(centerX - 48, groundY - 72),
          Offset(centerX - 44, groundY - 36),
          t,
        );
        final hip = lerpOffset(
          Offset(centerX + 6, groundY - 62),
          Offset(centerX + 10, groundY - 30),
          t,
        );
        skeleton(
          head: lerpOffset(
            Offset(centerX - 74, groundY - 82),
            Offset(centerX - 70, groundY - 48),
            t,
          ),
          shoulder: shoulder,
          hip: hip,
          leftHand: Offset(centerX - 92, groundY - 10),
          rightHand: Offset(centerX - 42, groundY - 10),
          leftKnee: hip,
          rightKnee: hip,
          leftFoot: Offset(centerX + 82, groundY - 12),
          rightFoot: Offset(centerX + 108, groundY - 12),
        );
        break;
      case 'press':
        final raise = Curves.easeInOut.transform(t);
        final shoulder = Offset(centerX, groundY - 116);
        final hip = Offset(centerX, groundY - 58);
        skeleton(
          head: Offset(centerX, groundY - 148),
          shoulder: shoulder,
          hip: hip,
          leftHand: lerpOffset(
            Offset(centerX - 42, groundY - 90),
            Offset(centerX - 18, groundY - 178),
            raise,
          ),
          rightHand: lerpOffset(
            Offset(centerX + 42, groundY - 90),
            Offset(centerX + 18, groundY - 178),
            raise,
          ),
          leftKnee: Offset(centerX - 18, groundY - 18),
          rightKnee: Offset(centerX + 18, groundY - 18),
          leftFoot: Offset(centerX - 22, groundY + 12),
          rightFoot: Offset(centerX + 22, groundY + 12),
        );
        canvas.drawLine(
          lerpOffset(
            Offset(centerX - 56, groundY - 96),
            Offset(centerX - 32, groundY - 182),
            raise,
          ),
          lerpOffset(
            Offset(centerX + 56, groundY - 96),
            Offset(centerX + 32, groundY - 182),
            raise,
          ),
          accentSoft,
        );
        break;
      case 'squat':
        final shoulder = lerpOffset(
          Offset(centerX, groundY - 126),
          Offset(centerX - 8, groundY - 94),
          t,
        );
        final hip = lerpOffset(
          Offset(centerX, groundY - 70),
          Offset(centerX, groundY - 40),
          t,
        );
        skeleton(
          head: lerpOffset(
            Offset(centerX, groundY - 158),
            Offset(centerX - 8, groundY - 126),
            t,
          ),
          shoulder: shoulder,
          hip: hip,
          leftHand: lerpOffset(
            Offset(centerX - 34, groundY - 118),
            Offset(centerX - 46, groundY - 80),
            t,
          ),
          rightHand: lerpOffset(
            Offset(centerX + 34, groundY - 118),
            Offset(centerX + 46, groundY - 80),
            t,
          ),
          leftKnee: lerpOffset(
            Offset(centerX - 22, groundY - 22),
            Offset(centerX - 42, groundY - 6),
            t,
          ),
          rightKnee: lerpOffset(
            Offset(centerX + 22, groundY - 22),
            Offset(centerX + 42, groundY - 6),
            t,
          ),
          leftFoot: Offset(centerX - 46, groundY + 8),
          rightFoot: Offset(centerX + 46, groundY + 8),
        );
        break;
      case 'row':
        final pull = Curves.easeInOut.transform(t);
        final shoulder = Offset(centerX - 10, groundY - 92);
        final hip = Offset(centerX + 20, groundY - 56);
        final hand = lerpOffset(
          Offset(centerX + 74, groundY - 52),
          Offset(centerX + 20, groundY - 82),
          pull,
        );
        skeleton(
          head: Offset(centerX - 24, groundY - 118),
          shoulder: shoulder,
          hip: hip,
          leftHand: hand,
          rightHand: hand + const Offset(18, -2),
          leftKnee: Offset(centerX + 6, groundY - 8),
          rightKnee: Offset(centerX + 36, groundY - 10),
          leftFoot: Offset(centerX - 6, groundY + 14),
          rightFoot: Offset(centerX + 56, groundY + 12),
        );
        canvas.drawLine(Offset(centerX + 98, groundY - 40), hand, accentSoft);
        break;
      case 'pull':
        final pull = Curves.easeInOut.transform(t);
        final shoulder = Offset(centerX, groundY - 120);
        final hip = Offset(centerX, groundY - 72);
        skeleton(
          head: Offset(centerX, groundY - 154),
          shoulder: shoulder,
          hip: hip,
          leftHand: lerpOffset(
            Offset(centerX - 54, groundY - 198),
            Offset(centerX - 34, groundY - 128),
            pull,
          ),
          rightHand: lerpOffset(
            Offset(centerX + 54, groundY - 198),
            Offset(centerX + 34, groundY - 128),
            pull,
          ),
          leftKnee: Offset(centerX - 20, groundY - 22),
          rightKnee: Offset(centerX + 20, groundY - 22),
          leftFoot: Offset(centerX - 28, groundY + 10),
          rightFoot: Offset(centerX + 28, groundY + 10),
        );
        canvas.drawLine(
          Offset(centerX - 82, groundY - 204),
          Offset(centerX + 82, groundY - 204),
          guide,
        );
        break;
      case 'raise':
        final lift = Curves.easeInOut.transform(t);
        final shoulder = Offset(centerX, groundY - 116);
        final hip = Offset(centerX, groundY - 58);
        skeleton(
          head: Offset(centerX, groundY - 148),
          shoulder: shoulder,
          hip: hip,
          leftHand: lerpOffset(
            Offset(centerX - 34, groundY - 72),
            Offset(centerX - 84, groundY - 122),
            lift,
          ),
          rightHand: lerpOffset(
            Offset(centerX + 34, groundY - 72),
            Offset(centerX + 84, groundY - 122),
            lift,
          ),
          leftKnee: Offset(centerX - 18, groundY - 18),
          rightKnee: Offset(centerX + 18, groundY - 18),
          leftFoot: Offset(centerX - 24, groundY + 12),
          rightFoot: Offset(centerX + 24, groundY + 12),
        );
        break;
      case 'curl':
        final curl = Curves.easeInOut.transform(t);
        final shoulder = Offset(centerX, groundY - 118);
        final hip = Offset(centerX, groundY - 60);
        skeleton(
          head: Offset(centerX, groundY - 150),
          shoulder: shoulder,
          hip: hip,
          leftHand: lerpOffset(
            Offset(centerX - 34, groundY - 54),
            Offset(centerX - 26, groundY - 102),
            curl,
          ),
          rightHand: lerpOffset(
            Offset(centerX + 34, groundY - 54),
            Offset(centerX + 26, groundY - 102),
            curl,
          ),
          leftKnee: Offset(centerX - 18, groundY - 18),
          rightKnee: Offset(centerX + 18, groundY - 18),
          leftFoot: Offset(centerX - 22, groundY + 12),
          rightFoot: Offset(centerX + 22, groundY + 12),
        );
        break;
      case 'pushdown':
        final press = Curves.easeInOut.transform(t);
        final shoulder = Offset(centerX, groundY - 116);
        final hip = Offset(centerX, groundY - 58);
        final leftHand = lerpOffset(
          Offset(centerX - 18, groundY - 104),
          Offset(centerX - 28, groundY - 38),
          press,
        );
        final rightHand = lerpOffset(
          Offset(centerX + 18, groundY - 104),
          Offset(centerX + 28, groundY - 38),
          press,
        );
        skeleton(
          head: Offset(centerX, groundY - 148),
          shoulder: shoulder,
          hip: hip,
          leftHand: leftHand,
          rightHand: rightHand,
          leftKnee: Offset(centerX - 18, groundY - 18),
          rightKnee: Offset(centerX + 18, groundY - 18),
          leftFoot: Offset(centerX - 24, groundY + 12),
          rightFoot: Offset(centerX + 24, groundY + 12),
        );
        canvas.drawLine(
          Offset(centerX - 18, groundY - 160),
          leftHand,
          accentSoft,
        );
        canvas.drawLine(
          Offset(centerX + 18, groundY - 160),
          rightHand,
          accentSoft,
        );
        break;
      case 'lunge':
        final shoulder = lerpOffset(
          Offset(centerX, groundY - 122),
          Offset(centerX + 4, groundY - 112),
          t,
        );
        final hip = lerpOffset(
          Offset(centerX, groundY - 66),
          Offset(centerX + 4, groundY - 54),
          t,
        );
        skeleton(
          head: lerpOffset(
            Offset(centerX, groundY - 154),
            Offset(centerX + 4, groundY - 144),
            t,
          ),
          shoulder: shoulder,
          hip: hip,
          leftHand: Offset(centerX - 26, groundY - 88),
          rightHand: Offset(centerX + 28, groundY - 86),
          leftKnee: Offset(centerX - 24, groundY - 12),
          rightKnee: lerpOffset(
            Offset(centerX + 26, groundY - 16),
            Offset(centerX + 50, groundY - 2),
            t,
          ),
          leftFoot: Offset(centerX - 36, groundY + 12),
          rightFoot: Offset(centerX + 78, groundY + 12),
        );
        break;
      case 'bridge':
        final shoulder = Offset(centerX - 48, groundY - 22);
        final hip = lerpOffset(
          Offset(centerX + 2, groundY - 18),
          Offset(centerX + 2, groundY - 58),
          t,
        );
        skeleton(
          head: Offset(centerX - 82, groundY - 26),
          shoulder: shoulder,
          hip: hip,
          leftHand: Offset(centerX - 70, groundY - 6),
          rightHand: Offset(centerX - 58, groundY - 2),
          leftKnee: Offset(centerX + 44, groundY - 42),
          rightKnee: Offset(centerX + 54, groundY - 38),
          leftFoot: Offset(centerX + 78, groundY + 10),
          rightFoot: Offset(centerX + 90, groundY + 10),
        );
        break;
      case 'core':
        final extend = Curves.easeInOut.transform(t);
        final shoulder = Offset(centerX - 6, groundY - 44);
        final hip = Offset(centerX + 18, groundY - 36);
        skeleton(
          head: Offset(centerX - 34, groundY - 50),
          shoulder: shoulder,
          hip: hip,
          leftHand: lerpOffset(
            Offset(centerX - 58, groundY - 80),
            Offset(centerX - 112, groundY - 110),
            extend,
          ),
          rightHand: lerpOffset(
            Offset(centerX - 10, groundY - 88),
            Offset(centerX + 16, groundY - 124),
            extend,
          ),
          leftKnee: lerpOffset(
            Offset(centerX + 54, groundY - 68),
            Offset(centerX + 94, groundY - 38),
            extend,
          ),
          rightKnee: lerpOffset(
            Offset(centerX + 62, groundY - 20),
            Offset(centerX + 120, groundY + 2),
            extend,
          ),
          leftFoot: Offset(centerX + 108, groundY - 18),
          rightFoot: Offset(centerX + 128, groundY + 10),
        );
        break;
      case 'cardio':
        final spread = Curves.easeInOut.transform(t);
        final shoulder = Offset(centerX, groundY - 116);
        final hip = Offset(centerX, groundY - 58);
        skeleton(
          head: Offset(centerX, groundY - 148),
          shoulder: shoulder,
          hip: hip,
          leftHand: lerpOffset(
            Offset(centerX - 26, groundY - 72),
            Offset(centerX - 86, groundY - 148),
            spread,
          ),
          rightHand: lerpOffset(
            Offset(centerX + 26, groundY - 72),
            Offset(centerX + 86, groundY - 148),
            spread,
          ),
          leftKnee: lerpOffset(
            Offset(centerX - 16, groundY - 20),
            Offset(centerX - 46, groundY - 8),
            spread,
          ),
          rightKnee: lerpOffset(
            Offset(centerX + 16, groundY - 20),
            Offset(centerX + 46, groundY - 8),
            spread,
          ),
          leftFoot: lerpOffset(
            Offset(centerX - 20, groundY + 12),
            Offset(centerX - 72, groundY + 14),
            spread,
          ),
          rightFoot: lerpOffset(
            Offset(centerX + 20, groundY + 12),
            Offset(centerX + 72, groundY + 14),
            spread,
          ),
          limbPaint: accentSoft,
        );
        break;
      default:
        final wave = math.sin(progress * math.pi * 2) * 6;
        skeleton(
          head: Offset(centerX, groundY - 148 + wave),
          shoulder: Offset(centerX, groundY - 116),
          hip: Offset(centerX, groundY - 58),
          leftHand: Offset(centerX - 42, groundY - 82),
          rightHand: Offset(centerX + 42, groundY - 82),
          leftKnee: Offset(centerX - 18, groundY - 18),
          rightKnee: Offset(centerX + 18, groundY - 18),
          leftFoot: Offset(centerX - 24, groundY + 12),
          rightFoot: Offset(centerX + 24, groundY + 12),
        );
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _ExerciseMotionPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.motionKey != motionKey;
  }
}

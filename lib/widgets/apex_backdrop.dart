import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../constants/colors.dart';

class ApexBackdrop extends StatefulWidget {
  final Widget child;

  const ApexBackdrop({super.key, required this.child});

  @override
  State<ApexBackdrop> createState() => _ApexBackdropState();
}

class _ApexBackdropState extends State<ApexBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

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
        return Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    ApexColors.bg,
                    Color(0xFFF6F8FB),
                    Color(0xFFEEF2F5),
                  ],
                ),
              ),
            ),
            _GlowBlob(
              alignment: const Alignment(-1.0, -0.9),
              color: ApexColors.glowRed,
              size: 290,
              xOffset: math.sin(_controller.value * math.pi * 2) * 20,
              yOffset: math.cos(_controller.value * math.pi * 1.6) * 18,
            ),
            _GlowBlob(
              alignment: const Alignment(1.0, -0.35),
              color: ApexColors.glowBlue,
              size: 320,
              xOffset: math.sin(_controller.value * math.pi * 2 + 1.4) * 26,
              yOffset: math.cos(_controller.value * math.pi * 1.7 + 0.9) * 22,
            ),
            _GlowBlob(
              alignment: const Alignment(-0.45, 0.95),
              color: ApexColors.glowGreen,
              size: 340,
              xOffset: math.sin(_controller.value * math.pi * 2 + 2.4) * 18,
              yOffset: math.cos(_controller.value * math.pi * 1.45 + 2.1) * 24,
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withAlpha(70),
                      Colors.white.withAlpha(155),
                      const Color(0xFFF7F8FB),
                    ],
                  ),
                ),
              ),
            ),
            widget.child,
          ],
        );
      },
    );
  }
}

class _GlowBlob extends StatelessWidget {
  final Alignment alignment;
  final Color color;
  final double size;
  final double xOffset;
  final double yOffset;

  const _GlowBlob({
    required this.alignment,
    required this.color,
    required this.size,
    required this.xOffset,
    required this.yOffset,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Transform.translate(
        offset: Offset(xOffset, yOffset),
        child: IgnorePointer(
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 62, sigmaY: 62),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    color.withAlpha(120),
                    color.withAlpha(40),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.46, 1.0],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

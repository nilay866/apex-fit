import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants/colors.dart';

class ApexCard extends StatefulWidget {
  final Widget child;
  final bool glow;
  final Color? glowColor;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final bool floating;

  const ApexCard({
    super.key,
    required this.child,
    this.glow = false,
    this.glowColor,
    this.padding,
    this.onTap,
    this.floating = true,
  });

  @override
  State<ApexCard> createState() => _ApexCardState();
}

class _ApexCardState extends State<ApexCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glow = widget.glowColor ?? ApexColors.accentSoft;
    final radius = BorderRadius.circular(28);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final dy = widget.floating
            ? math.sin(_controller.value * math.pi * 2) * (widget.glow ? 2.6 : 1.6)
            : 0.0;

        return Transform.translate(
          offset: Offset(0, dy),
          child: child,
        );
      },
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: radius,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: widget.padding ?? const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [ApexColors.card, ApexColors.cardAlt],
              ),
              border: Border.all(
                color: widget.glow ? glow.withAlpha(84) : ApexColors.borderStrong,
              ),
              boxShadow: [
                BoxShadow(
                  color: ApexColors.shadow.withAlpha(widget.glow ? 52 : 36),
                  blurRadius: widget.glow ? 26 : 22,
                  offset: const Offset(0, 14),
                ),
                if (widget.glow)
                  BoxShadow(
                    color: glow.withAlpha(18),
                    blurRadius: 32,
                    spreadRadius: 2,
                  ),
              ],
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

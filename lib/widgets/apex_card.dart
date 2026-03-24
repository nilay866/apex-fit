import 'package:flutter/material.dart';
import '../constants/colors.dart';

class ApexCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(20);

    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: radius,
            color: ApexColors.card,
            border: glow
                ? Border.all(
                    color: (glowColor ?? ApexColors.accent).withAlpha(40),
                  )
                : null,
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 24,
                spreadRadius: 0,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

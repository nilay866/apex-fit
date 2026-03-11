import 'dart:math' as math;
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
    this.floating = true, // We keep the param so we don't break existing usages, but it does nothing now
  });

  @override
  Widget build(BuildContext context) {
    final glowC = glowColor ?? ApexColors.accentSoft;
    final radius = BorderRadius.circular(28);

    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          padding: padding ?? const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: radius,
            color: ApexColors.card,
            border: Border.all(
              color: glow ? glowC.withAlpha(84) : ApexColors.border,
            ),
            boxShadow: [
              // Keep shadows extremely minimal for a clean modern flat look
              BoxShadow(
                color: ApexColors.shadow.withAlpha(16),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

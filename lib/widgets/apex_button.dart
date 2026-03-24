import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';

enum ApexButtonTone { primary, soft, outline, ghost }

class ApexButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color color;
  final bool outline;
  final bool full;
  final bool sm;
  final bool loading;
  final bool disabled;
  final IconData? icon;
  final ApexButtonTone? tone;

  const ApexButton({
    super.key,
    required this.text,
    this.onPressed,
    this.color = ApexColors.accent,
    this.outline = false,
    this.full = false,
    this.sm = false,
    this.loading = false,
    this.disabled = false,
    this.icon,
    this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedTone = outline
        ? ApexButtonTone.outline
        : tone ?? (color == ApexColors.accent ? ApexButtonTone.primary : ApexButtonTone.soft);
    final isPrimary = resolvedTone == ApexButtonTone.primary;
    final isSoft = resolvedTone == ApexButtonTone.soft;
    final isOutline = resolvedTone == ApexButtonTone.outline;

    final backgroundColor = switch (resolvedTone) {
      ApexButtonTone.primary => color,
      ApexButtonTone.soft => color.withAlpha(34),
      ApexButtonTone.outline => Colors.transparent,
      ApexButtonTone.ghost => ApexColors.surface.withAlpha(150),
    };

    final foregroundColor = switch (resolvedTone) {
      ApexButtonTone.primary => color.computeLuminance() > 0.55 ? ApexColors.accent : ApexColors.ink,
      ApexButtonTone.soft => color,
      ApexButtonTone.outline => color,
      ApexButtonTone.ghost => ApexColors.t1,
    };

    final borderColor = switch (resolvedTone) {
      ApexButtonTone.primary => color.withAlpha(180),
      ApexButtonTone.soft => color.withAlpha(72),
      ApexButtonTone.outline => color.withAlpha(132),
      ApexButtonTone.ghost => ApexColors.border,
    };

    return SizedBox(
      width: full ? double.infinity : null,
      height: sm ? 42 : 54,
      child: ElevatedButton(
        onPressed: disabled || loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          disabledBackgroundColor: backgroundColor.withAlpha(120),
          disabledForegroundColor: foregroundColor.withAlpha(120),
          elevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(sm ? 16 : 20),
            side: BorderSide(color: borderColor, width: 1.1),
          ),
          padding: EdgeInsets.symmetric(horizontal: sm ? 16 : 20),
        ).copyWith(
          overlayColor: WidgetStatePropertyAll(foregroundColor.withAlpha(18)),
        ),
        child: loading
            ? SizedBox(
                width: sm ? 15 : 18,
                height: sm ? 15 : 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: foregroundColor,
                ),
              )
            : Row(
                mainAxisSize: full ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: sm ? 14 : 16),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      text,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: sm ? 12 : 14,
                        letterSpacing: isSoft || isOutline ? 0.0 : -0.2,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

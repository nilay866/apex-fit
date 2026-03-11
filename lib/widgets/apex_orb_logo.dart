import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';

enum ApexOrbVariant { dark, light }

class ApexOrbLogo extends StatefulWidget {
  final double size;
  final String label;
  final String? imageData;
  final VoidCallback? onTap;
  final bool showEditBadge;
  final IconData badgeIcon;
  final bool elevated;
  final ApexOrbVariant variant;

  const ApexOrbLogo({
    super.key,
    required this.size,
    required this.label,
    this.imageData,
    this.onTap,
    this.showEditBadge = false,
    this.badgeIcon = Icons.north_east_rounded,
    this.elevated = true,
    this.variant = ApexOrbVariant.dark,
  });

  @override
  State<ApexOrbLogo> createState() => _ApexOrbLogoState();
}

class _ApexOrbLogoState extends State<ApexOrbLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  bool get _isLight => widget.variant == ApexOrbVariant.light;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initials = _buildInitials(widget.label);
    final orb = AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            clipBehavior: Clip.none,
            fit: StackFit.expand,
            children: [
              Transform.rotate(
                angle: _controller.value * math.pi * 2,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(colors: _ringColors),
                    boxShadow: widget.elevated
                        ? [
                            BoxShadow(
                              color: _shadowColor,
                              blurRadius: widget.size * 0.34,
                              offset: Offset(0, widget.size * 0.14),
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(widget.size * 0.06),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _frameBorder),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: _frameGradient,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(widget.size * 0.12),
                child: ClipOval(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: _innerGradient,
                      ),
                    ),
                    child: _imageWidget(initials),
                  ),
                ),
              ),
              IgnorePointer(
                child: Padding(
                  padding: EdgeInsets.all(widget.size * 0.12),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: const Alignment(0.3, 0.8),
                        colors: _highlightGradient,
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.showEditBadge)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: widget.size * 0.25,
                    height: widget.size * 0.25,
                    decoration: BoxDecoration(
                      color: _badgeFill,
                      shape: BoxShape.circle,
                      border: Border.all(color: _badgeBorder),
                      boxShadow: [
                        BoxShadow(
                          color: _shadowColor.withAlpha(80),
                          blurRadius: widget.size * 0.1,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      widget.badgeIcon,
                      size: widget.size * 0.1,
                      color: _badgeIcon,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );

    return GestureDetector(
      onTap: widget.onTap,
      child: RepaintBoundary(child: orb),
    );
  }

  Widget _imageWidget(String initials) {
    final imageData = widget.imageData;
    final int cacheSize = (widget.size * MediaQuery.of(context).devicePixelRatio).round();
    
    if (imageData != null && imageData.isNotEmpty) {
      if (imageData.startsWith('data:')) {
        final base64String = imageData.split(',').last;
        try {
          final decoded = base64Decode(base64String.replaceAll(RegExp(r'\s+'), ''));
          return Image.memory(
            decoded, 
            fit: BoxFit.cover,
            gaplessPlayback: true,
            cacheWidth: cacheSize,
            cacheHeight: cacheSize,
            errorBuilder: (context, error, stackTrace) => _initialsWidget(initials),
          );
        } catch (e) {
          return _initialsWidget(initials);
        }
      }
      if (imageData.startsWith('http')) {
        return Image.network(
          imageData, 
          fit: BoxFit.cover,
          gaplessPlayback: true,
          cacheWidth: cacheSize,
          cacheHeight: cacheSize,
          errorBuilder: (context, error, stackTrace) => _initialsWidget(initials),
        );
      }
    }

    return _initialsWidget(initials);
  }

  Widget _initialsWidget(String initials) {
    return Center(
      child: Text(
        initials,
        style: GoogleFonts.inter(
          fontSize: widget.size * 0.23,
          fontWeight: FontWeight.w700,
          color: _textColor,
          letterSpacing: -widget.size * 0.01,
        ),
      ),
    );
  }

  List<Color> get _ringColors {
    if (_isLight) {
      return [
        const Color(0x90FF6B6B),
        const Color(0x905AA9FF),
        const Color(0x907DFF8A),
        const Color(0x90FFFFFF),
        const Color(0x90FF6B6B),
      ];
    }
    return [
      ApexColors.accent.withAlpha(210),
      ApexColors.blue.withAlpha(170),
      ApexColors.purple.withAlpha(160),
      ApexColors.accentSoft.withAlpha(190),
      ApexColors.accent.withAlpha(210),
    ];
  }

  List<Color> get _frameGradient {
    if (_isLight) {
      return const [Color(0xFFFFFFFF), Color(0xFFF2F5F8)];
    }
    return const [ApexColors.bg, ApexColors.cardAlt];
  }

  List<Color> get _innerGradient {
    if (_isLight) {
      return const [Color(0xFFFFFFFF), Color(0xFFECEFF3)];
    }
    return const [ApexColors.accent, ApexColors.blue];
  }

  List<Color> get _highlightGradient {
    if (_isLight) {
      return [
        Colors.white.withAlpha(165),
        Colors.white.withAlpha(25),
        Colors.transparent,
      ];
    }
    return [
      Colors.white.withAlpha(68),
      Colors.transparent,
      Colors.transparent,
    ];
  }

  Color get _frameBorder => _isLight ? const Color(0x220F172A) : ApexColors.borderStrong;
  Color get _shadowColor => _isLight ? const Color(0x200F172A) : ApexColors.shadow.withAlpha(88);
  Color get _badgeFill => _isLight ? const Color(0xF8FFFFFF) : ApexColors.cardAlt;
  Color get _badgeBorder => _isLight ? const Color(0x220F172A) : ApexColors.borderStrong;
  Color get _badgeIcon => _isLight ? const Color(0xFF171A1E) : ApexColors.t1;
  Color get _textColor => _isLight ? const Color(0xFF171A1E) : ApexColors.ink;

  static String _buildInitials(String label) {
    final parts = label
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return 'AP';
    }
    if (parts.length == 1) {
      final single = parts.first;
      final end = single.length.clamp(1, 2);
      return single.substring(0, end).toUpperCase();
    }
    return (parts.first[0] + parts[1][0]).toUpperCase();
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';

class MacroBar extends StatefulWidget {
  final String label;
  final double value;
  final double goal;
  final Color color;

  const MacroBar({
    super.key,
    required this.label,
    required this.value,
    required this.goal,
    required this.color,
  });

  @override
  State<MacroBar> createState() => _MacroBarState();
}

class _MacroBarState extends State<MacroBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _targetPct = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _targetPct =
        widget.goal > 0 ? (widget.value / widget.goal).clamp(0.0, 1.0) : 0.0;
    _animation = Tween<double>(begin: 0, end: _targetPct).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(MacroBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newPct = widget.goal > 0
        ? (widget.value / widget.goal).clamp(0.0, 1.0)
        : 0.0;
    if (newPct != _targetPct) {
      _animation = Tween<double>(
        begin: _animation.value,
        end: newPct,
      ).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
      _targetPct = newPct;
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: ApexColors.t2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              RichText(
                text: TextSpan(
                  style: GoogleFonts.dmMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: widget.color,
                  ),
                  children: [
                    TextSpan(text: '${widget.value.round()}'),
                    TextSpan(
                      text: '/${widget.goal.round()}',
                      style: const TextStyle(color: ApexColors.t3),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          AnimatedBuilder(
            animation: _animation,
            builder: (_, __) => ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: _animation.value,
                minHeight: 7,
                backgroundColor: ApexColors.border,
                valueColor: AlwaysStoppedAnimation(widget.color),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

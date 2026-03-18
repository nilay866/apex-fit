import 'package:flutter/material.dart';
import 'package:apex_ai/constants/colors.dart';
import 'package:google_fonts/google_fonts.dart';

class QuickActionFab extends StatelessWidget {
  final VoidCallback onStartWorkout;
  final VoidCallback onLogMeal;
  final VoidCallback onAddWater;

  const QuickActionFab({
    super.key,
    required this.onStartWorkout,
    required this.onLogMeal,
    required this.onAddWater,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Primary CTA: Full-width black pill ──────────────────
          GestureDetector(
            onTap: onStartWorkout,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: ApexColors.darkAction,
                borderRadius: BorderRadius.circular(50),
                boxShadow: [
                  BoxShadow(
                    color: ApexColors.darkAction.withAlpha(40),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.play_arrow_rounded,
                    color: ApexColors.ink,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Quick Start Workout',
                    style: GoogleFonts.inter(
                      color: ApexColors.ink,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          // ── Secondary actions row ──────────────────────────────
          Row(
            children: [
              Expanded(
                child: _secondaryAction(
                  icon: Icons.restaurant_rounded,
                  label: 'Log Meal',
                  color: ApexColors.accent,
                  onTap: onLogMeal,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _secondaryAction(
                  icon: Icons.water_drop_rounded,
                  label: 'Water',
                  color: ApexColors.blue,
                  onTap: onAddWater,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _secondaryAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withAlpha(15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: ApexColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ApexColors.borderStrong),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(60),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          _fabItem(
            icon: Icons.fitness_center_rounded,
            label: 'Workout',
            color: ApexColors.accent,
            onTap: onStartWorkout,
            flex: 2,
          ),
          const SizedBox(width: 6),
          _fabItem(
            icon: Icons.restaurant_rounded,
            label: 'Meal',
            color: ApexColors.orange,
            onTap: onLogMeal,
            flex: 1,
          ),
          const SizedBox(width: 6),
          _fabItem(
            icon: Icons.water_drop_rounded,
            label: 'Water',
            color: ApexColors.blue,
            onTap: onAddWater,
            flex: 1,
          ),
        ],
      ),
    );
  }

  Widget _fabItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required int flex,
  }) {
    return Expanded(
      flex: flex,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: color.withAlpha(20),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withAlpha(60)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

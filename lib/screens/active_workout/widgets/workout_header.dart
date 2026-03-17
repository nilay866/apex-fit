import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../constants/colors.dart';
import '../../../constants/theme.dart';

class ActiveWorkoutHeader extends StatelessWidget {
  final String workoutName;
  final int doneCount;
  final int totalCount;
  final num totalVolume;
  final String elapsedLabel;

  const ActiveWorkoutHeader({
    super.key,
    required this.workoutName,
    required this.doneCount,
    required this.totalCount,
    required this.totalVolume,
    required this.elapsedLabel,
  });

  @override
  Widget build(BuildContext context) {
    final progress = totalCount > 0 ? doneCount / totalCount : 0.0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ApexColors.surface,
        border: Border(bottom: BorderSide(color: ApexColors.border)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    workoutName,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: ApexColors.t1,
                    ),
                  ),
                  Text(
                    '$doneCount/$totalCount sets · ${totalVolume}kg',
                    style: const TextStyle(color: ApexColors.t2, fontSize: 10),
                  ),
                ],
              ),
              Text(
                elapsedLabel,
                style: ApexTheme.mono(size: 24, color: ApexColors.accent),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 3,
              backgroundColor: ApexColors.border,
              valueColor: const AlwaysStoppedAnimation(ApexColors.accent),
            ),
          ),
        ],
      ),
    );
  }
}

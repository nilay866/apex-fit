import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';
import '../services/achievement_service.dart';

class AchievementBadge extends StatelessWidget {
  final Achievement achievement;
  final bool unlocked;

  const AchievementBadge({
    super.key,
    required this.achievement,
    this.unlocked = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(int.parse(achievement.color));
    
    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: unlocked 
                  ? [color.withAlpha(200), color.withAlpha(100)]
                  : [ApexColors.surface, ApexColors.border.withAlpha(100)],
              ),
              border: Border.all(
                color: unlocked ? color : ApexColors.border,
                width: 2,
              ),
              boxShadow: unlocked ? [
                BoxShadow(
                  color: color.withAlpha(80),
                  blurRadius: 15,
                  spreadRadius: 2,
                )
              ] : null,
            ),
            child: Icon(
              IconData(AchievementService.getIconData(achievement.icon), fontFamily: 'MaterialIcons'),
              color: unlocked ? Colors.white : ApexColors.t3,
              size: 32,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            achievement.title,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: unlocked ? ApexColors.t1 : ApexColors.t3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            unlocked ? 'UNLOCKED' : 'LOCKED',
            style: GoogleFonts.inter(
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
              color: unlocked ? color : ApexColors.t3.withAlpha(150),
            ),
          ),
        ],
      ),
    );
  }
}

class AchievementList extends StatelessWidget {
  final List<Achievement> unlockedAchievements;

  const AchievementList({super.key, required this.unlockedAchievements});

  @override
  Widget build(BuildContext context) {
    if (unlockedAchievements.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ACHIEVEMENTS',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: ApexColors.t2,
                ),
              ),
              Text(
                '${unlockedAchievements.length} UNLOCKED',
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: ApexColors.accent,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 130,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: unlockedAchievements.length,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemBuilder: (context, index) {
              return AchievementBadge(achievement: unlockedAchievements[index]);
            },
          ),
        ),
      ],
    );
  }
}

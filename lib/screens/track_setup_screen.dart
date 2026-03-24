import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';
import '../widgets/apex_card.dart';

/// Activity type picker with one-hand UX. Large thumb-zone buttons.
class TrackSetupScreen extends StatelessWidget {
  final void Function(Map<String, dynamic> workout) onStartWorkout;
  const TrackSetupScreen({super.key, required this.onStartWorkout});

  static const _activities = [
    {
      'type': 'run',
      'name': 'Outdoor Run',
      'icon': Icons.directions_run_rounded,
      'color': 0xFF4FC3F7,
      'description': 'GPS route tracking with pace & splits',
    },
    {
      'type': 'walk',
      'name': 'Walk',
      'icon': Icons.directions_walk_rounded,
      'color': 0xFF81C784,
      'description': 'Track your daily walks',
    },
    {
      'type': 'cycle',
      'name': 'Cycling',
      'icon': Icons.directions_bike_rounded,
      'color': 0xFFFFB74D,
      'description': 'Road, MTB or indoor cycling',
    },
    {
      'type': 'hike',
      'name': 'Hiking',
      'icon': Icons.terrain_rounded,
      'color': 0xFF4DB6AC,
      'description': 'Trail tracking with elevation',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          // Header
          Text(
            'TRACK',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: ApexColors.t3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Start Activity',
            style: GoogleFonts.inter(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: ApexColors.t1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose an activity to start GPS tracking.',
            style: const TextStyle(fontSize: 13, color: ApexColors.t2),
          ),
          const SizedBox(height: 24),

          // Activity cards — large thumb targets
          ..._activities.map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    onStartWorkout({
                      'name': a['name'],
                      'type': 'cardio',
                      'activityType': a['type'],
                    });
                  },
                  child: ApexCard(
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Color(a['color'] as int).withAlpha(25),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            a['icon'] as IconData,
                            color: Color(a['color'] as int),
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                a['name'] as String,
                                style: GoogleFonts.inter(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: ApexColors.t1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                a['description'] as String,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: ApexColors.t3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: ApexColors.t3,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              )),

          const SizedBox(height: 20),

          // Quick stats teaser
          ApexCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RECENT ACTIVITY',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: ApexColors.t3,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _miniStat('This Week', '0 km', ApexColors.accent),
                    _miniStat('Activities', '0', ApexColors.blue),
                    _miniStat('Calories', '0', ApexColors.orange),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: ApexColors.t3,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

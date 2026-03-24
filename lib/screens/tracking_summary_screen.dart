import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';
import '../widgets/apex_card.dart';
import '../widgets/apex_button.dart';
import '../services/activity_tracking_service.dart';
import '../repositories/activity_repository.dart';

/// Post-activity summary: stats, splits, save.
class TrackingSummaryScreen extends StatefulWidget {
  final String activityType;
  final double distanceKm;
  final int durationSeconds;
  final double elevationGain;
  final double elevationLoss;
  final double avgPace;
  final double maxSpeed;
  final List<Map<String, dynamic>> splits;
  final List<Map<String, dynamic>> gpsPoints;
  final double userWeightKg;

  const TrackingSummaryScreen({
    super.key,
    required this.activityType,
    required this.distanceKm,
    required this.durationSeconds,
    this.elevationGain = 0,
    this.elevationLoss = 0,
    this.avgPace = 0,
    this.maxSpeed = 0,
    this.splits = const [],
    this.gpsPoints = const [],
    this.userWeightKg = 70,
  });

  @override
  State<TrackingSummaryScreen> createState() => _TrackingSummaryScreenState();
}

class _TrackingSummaryScreenState extends State<TrackingSummaryScreen> {
  bool _saving = false;
  bool _saved = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final calories = ActivityTrackingService.estimateCalories(
        activityType: widget.activityType,
        weightKg: widget.userWeightKg,
        durationSeconds: widget.durationSeconds,
      );

      await activityRepository.saveActivity(
        type: widget.activityType,
        distanceKm: widget.distanceKm,
        durationSeconds: widget.durationSeconds,
        calories: calories,
        elevationGain: widget.elevationGain,
        elevationLoss: widget.elevationLoss,
        avgPace: widget.avgPace,
        avgSpeed: widget.distanceKm > 0 && widget.durationSeconds > 0
            ? (widget.distanceKm * 1000) / widget.durationSeconds
            : 0,
        maxSpeed: widget.maxSpeed,
        splits: widget.splits,
        gpsPoints: widget.gpsPoints,
      );

      if (mounted) setState(() => _saved = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save failed: $e'),
            backgroundColor: ApexColors.red,
          ),
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final calories = ActivityTrackingService.estimateCalories(
      activityType: widget.activityType,
      weightKg: widget.userWeightKg,
      durationSeconds: widget.durationSeconds,
    );

    return Scaffold(
      backgroundColor: ApexColors.bg,
      appBar: AppBar(
        backgroundColor: ApexColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded,
              color: ApexColors.t1, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Activity Summary',
          style: GoogleFonts.inter(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: ApexColors.t1),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          // Type + Duration hero
          ApexCard(
            glow: true,
            child: Column(
              children: [
                Icon(
                  _iconForType(widget.activityType),
                  color: ApexColors.accent,
                  size: 40,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.activityType.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: ApexColors.accent,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  ActivityTrackingService.formatDuration(
                      widget.durationSeconds),
                  style: GoogleFonts.inter(
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                    color: ApexColors.t1,
                    letterSpacing: -2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Stats grid
          Row(
            children: [
              Expanded(
                child: _statCard(
                  'Distance',
                  '${widget.distanceKm.toStringAsFixed(2)} km',
                  ApexColors.accent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statCard(
                  'Avg Pace',
                  ActivityTrackingService.formatPace(widget.avgPace),
                  ApexColors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _statCard(
                  'Calories',
                  '${calories.round()} kcal',
                  ApexColors.orange,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statCard(
                  'Elevation',
                  '↑${widget.elevationGain.round()}m ↓${widget.elevationLoss.round()}m',
                  ApexColors.yellow,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Splits
          if (widget.splits.isNotEmpty) ...[
            ApexCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SPLITS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: ApexColors.t3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...widget.splits.map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'km ${s['km']}',
                              style: const TextStyle(
                                color: ApexColors.t1,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              ActivityTrackingService.formatPace(
                                (s['pace'] as num?)?.toDouble() ?? 0,
                              ),
                              style: TextStyle(
                                color: ApexColors.accent,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Save button — thumb zone
          if (!_saved)
            ApexButton(
              text: 'Save Activity',
              onPressed: _save,
              full: true,
              loading: _saving,
            )
          else
            ApexCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: ApexColors.accent, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    'Activity Saved!',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: ApexColors.accent,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return ApexCard(
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: ApexColors.t3,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'run':
        return Icons.directions_run_rounded;
      case 'walk':
        return Icons.directions_walk_rounded;
      case 'cycle':
        return Icons.directions_bike_rounded;
      case 'hike':
        return Icons.terrain_rounded;
      default:
        return Icons.fitness_center_rounded;
    }
  }
}

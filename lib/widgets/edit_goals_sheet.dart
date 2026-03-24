import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';
import '../services/supabase_service.dart';
import 'apex_button.dart';

class EditGoalsSheet extends StatefulWidget {
  final int caloriesGoal;
  final int waterGoalMl;
  final int workoutGoalMin;
  final double sleepGoalHr;
  final VoidCallback onSaved;

  const EditGoalsSheet({
    super.key,
    required this.caloriesGoal,
    required this.waterGoalMl,
    required this.workoutGoalMin,
    required this.sleepGoalHr,
    required this.onSaved,
  });

  /// Convenience method to show the sheet from anywhere.
  static void show(
    BuildContext context, {
    required int caloriesGoal,
    required int waterGoalMl,
    required int workoutGoalMin,
    required double sleepGoalHr,
    required VoidCallback onSaved,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EditGoalsSheet(
        caloriesGoal: caloriesGoal,
        waterGoalMl: waterGoalMl,
        workoutGoalMin: workoutGoalMin,
        sleepGoalHr: sleepGoalHr,
        onSaved: () {
          onSaved();
          Navigator.pop(ctx);
        },
      ),
    );
  }

  @override
  State<EditGoalsSheet> createState() => _EditGoalsSheetState();
}

class _EditGoalsSheetState extends State<EditGoalsSheet> {
  late final TextEditingController _calC;
  late final TextEditingController _waterC;
  late final TextEditingController _workoutC;
  late final TextEditingController _sleepC;
  bool _saving = false;
  String _err = '';

  @override
  void initState() {
    super.initState();
    _calC = TextEditingController(text: '${widget.caloriesGoal}');
    _waterC = TextEditingController(
      text: (widget.waterGoalMl / 1000).toStringAsFixed(1),
    );
    _workoutC = TextEditingController(text: '${widget.workoutGoalMin}');
    _sleepC = TextEditingController(text: widget.sleepGoalHr.toStringAsFixed(1));
  }

  @override
  void dispose() {
    _calC.dispose();
    _waterC.dispose();
    _workoutC.dispose();
    _sleepC.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final cal = int.tryParse(_calC.text);
    final waterL = double.tryParse(_waterC.text);
    final workout = int.tryParse(_workoutC.text);
    final sleepHr = double.tryParse(_sleepC.text);

    if (cal == null || waterL == null || workout == null || sleepHr == null) {
      setState(() => _err = 'Please enter valid numbers.');
      return;
    }
    if (cal < 500 || cal > 10000) {
      setState(() => _err = 'Calories should be 500–10,000 kcal.');
      return;
    }
    if (waterL < 0.5 || waterL > 10) {
      setState(() => _err = 'Water should be 0.5–10 L.');
      return;
    }
    if (workout < 5 || workout > 300) {
      setState(() => _err = 'Workout duration should be 5–300 min.');
      return;
    }
    if (sleepHr < 2 || sleepHr > 20) {
      setState(() => _err = 'Sleep goal should be 2–20 hours.');
      return;
    }

    setState(() {
      _saving = true;
      _err = '';
    });

    try {
      final uid = SupabaseService.requireUserId(action: 'update your goals');
      await SupabaseService.updateProfile(uid, {
        'calorie_goal': cal,
        'water_goal_ml': (waterL * 1000).round(),
        'workout_goal_min': workout,
        'sleep_goal_hr': sleepHr,
      });
      widget.onSaved();
    } catch (e) {
      final msg = SupabaseService.describeError(e);
      if (mounted) setState(() => _err = msg);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: ApexColors.surfaceStrong,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: ApexColors.border),
            boxShadow: [
              BoxShadow(
                color: ApexColors.shadow.withAlpha(50),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: ApexColors.borderStrong,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  Text(
                    'Set Daily Goals',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      color: ApexColors.t1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Customize targets to match your training plan.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: ApexColors.t2,
                    ),
                  ),
                  const SizedBox(height: 22),

                  _goalField(
                    icon: Icons.local_fire_department_rounded,
                    label: 'Calories',
                    controller: _calC,
                    suffix: 'kcal',
                    color: ApexColors.accent,
                  ),
                  const SizedBox(height: 14),
                  _goalField(
                    icon: Icons.water_drop_rounded,
                    label: 'Water Intake',
                    controller: _waterC,
                    suffix: 'liters',
                    color: ApexColors.blue,
                    decimal: true,
                  ),
                  const SizedBox(height: 14),
                  _goalField(
                    icon: Icons.timer_rounded,
                    label: 'Workout Duration',
                    controller: _workoutC,
                    suffix: 'min',
                    color: ApexColors.green,
                  ),
                  const SizedBox(height: 14),
                  _goalField(
                    icon: Icons.bedtime_rounded,
                    label: 'Sleep Goal',
                    controller: _sleepC,
                    suffix: 'hours',
                    color: ApexColors.purple,
                    decimal: true,
                  ),

                  if (_err.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: ApexColors.red.withAlpha(15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              size: 14, color: ApexColors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _err,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: ApexColors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: ApexButton(
                          text: 'Cancel',
                          onPressed: () => Navigator.pop(context),
                          tone: ApexButtonTone.outline,
                          color: ApexColors.t1,
                          full: true,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ApexButton(
                          text: 'Save Goals',
                          onPressed: _save,
                          loading: _saving,
                          full: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _goalField({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    required String suffix,
    required Color color,
    bool decimal = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 10,
                color: ApexColors.t3,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: decimal
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.number,
          style: GoogleFonts.inter(
            fontSize: 16,
            color: ApexColors.t1,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            suffixText: suffix,
            suffixStyle: GoogleFonts.inter(
              color: ApexColors.t3,
              fontSize: 13,
            ),
            filled: true,
            fillColor: ApexColors.cardAlt,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: color, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }
}

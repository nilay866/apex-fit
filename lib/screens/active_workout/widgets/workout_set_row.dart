import 'package:flutter/material.dart';
import '../../../constants/colors.dart';
import '../../../constants/theme.dart';

class WorkoutSetRow extends StatefulWidget {
  final int setNumber;
  final Map<String, dynamic> setData;
  final String previousReps;
  final String previousWeight;
  final int? deltaPercent;
  final VoidCallback onToggleType;
  final ValueChanged<String> onRepsChanged;
  final ValueChanged<String> onWeightChanged;
  final VoidCallback onFieldTap;
  final VoidCallback onWeightLongPress;
  final VoidCallback onToggleDone;

  const WorkoutSetRow({
    super.key,
    required this.setNumber,
    required this.setData,
    required this.previousReps,
    required this.previousWeight,
    required this.deltaPercent,
    required this.onToggleType,
    required this.onRepsChanged,
    required this.onWeightChanged,
    required this.onFieldTap,
    required this.onWeightLongPress,
    required this.onToggleDone,
  });

  @override
  State<WorkoutSetRow> createState() => _WorkoutSetRowState();
}

class _WorkoutSetRowState extends State<WorkoutSetRow> {
  late final TextEditingController _repsController;
  late final TextEditingController _weightController;

  @override
  void initState() {
    super.initState();
    _repsController = TextEditingController(
      text: widget.setData['reps']?.toString() ?? '',
    );
    _weightController = TextEditingController(
      text: widget.setData['weight']?.toString() ?? '',
    );
  }

  @override
  void didUpdateWidget(covariant WorkoutSetRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncController(_repsController, widget.setData['reps']?.toString() ?? '');
    _syncController(
      _weightController,
      widget.setData['weight']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _repsController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _syncController(TextEditingController controller, String nextValue) {
    if (controller.text == nextValue) return;
    controller.value = TextEditingValue(
      text: nextValue,
      selection: TextSelection.collapsed(offset: nextValue.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final done = widget.setData['done'] == true;
    final typeValue = widget.setData['type'] as String? ?? 'normal';

    final (typeLabel, typeColor) = switch (typeValue) {
      'warmup' => ('W', ApexColors.yellow),
      'drop' => ('D', ApexColors.blue),
      'failure' => ('F', ApexColors.red),
      _ => ('${widget.setNumber}', ApexColors.t3),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: done ? ApexColors.accentDim : ApexColors.card,
        border: Border.all(
          color: done
              ? ApexColors.accent.withAlpha(64)
              : switch (typeValue) {
                  'warmup' => ApexColors.yellow.withAlpha(60),
                  'drop' => ApexColors.blue.withAlpha(60),
                  _ => ApexColors.border,
                },
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: GestureDetector(
              onTap: widget.onToggleType,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: done ? ApexColors.accent : typeColor.withAlpha(28),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: done ? ApexColors.accent : typeColor.withAlpha(100),
                  ),
                ),
                child: Center(
                  child: Text(
                    done ? '✓' : typeLabel,
                    style: TextStyle(
                      color: done ? ApexColors.bg : typeColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _repsController,
              onChanged: widget.onRepsChanged,
              onTap: widget.onFieldTap,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: ApexTheme.mono(size: 16),
              decoration: InputDecoration(
                hintText: widget.previousReps.isNotEmpty
                    ? widget.previousReps
                    : '0',
                hintStyle: ApexTheme.mono(
                  size: 14,
                  color: ApexColors.t3.withValues(alpha: 0.5),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                filled: true,
                fillColor: ApexColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(7),
                  borderSide: BorderSide(color: ApexColors.border),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: GestureDetector(
              onLongPress: widget.onWeightLongPress,
              child: AbsorbPointer(
                absorbing: false,
                child: TextField(
                  controller: _weightController,
                  onChanged: widget.onWeightChanged,
                  onTap: widget.onFieldTap,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: ApexTheme.mono(size: 16),
                  decoration: InputDecoration(
                    hintText: widget.previousWeight.isNotEmpty
                        ? widget.previousWeight
                        : '0',
                    hintStyle: ApexTheme.mono(
                      size: 14,
                      color: ApexColors.t3.withValues(alpha: 0.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    filled: true,
                    fillColor: ApexColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(7),
                      borderSide: BorderSide(color: ApexColors.border),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          if (done && widget.deltaPercent != null)
            Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color:
                    (widget.deltaPercent! > 0
                            ? ApexColors.accent
                            : ApexColors.red)
                        .withAlpha(25),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color:
                      (widget.deltaPercent! > 0
                              ? ApexColors.accent
                              : ApexColors.red)
                          .withAlpha(60),
                ),
              ),
              child: Text(
                '${widget.deltaPercent! > 0 ? '↑' : '↓'}${widget.deltaPercent!.abs()}%',
                style: TextStyle(
                  color: widget.deltaPercent! > 0
                      ? ApexColors.accent
                      : ApexColors.red,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          GestureDetector(
            onTap: widget.onToggleDone,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: done ? ApexColors.accent : ApexColors.surface,
                border: Border.all(
                  color: done ? ApexColors.accent : ApexColors.border,
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Center(
                child: Text(
                  done ? '✓' : '○',
                  style: TextStyle(
                    color: done ? ApexColors.bg : ApexColors.t2,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

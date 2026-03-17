import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../constants/colors.dart';
import '../../../widgets/apex_button.dart';

class SessionFooter extends StatelessWidget {
  final bool showConfirmation;
  final bool saving;
  final String elapsedLabel;
  final int doneCount;
  final num totalVolume;
  final String intensity;
  final TextEditingController notesController;
  final VoidCallback onBeginFinish;
  final VoidCallback onCancelFinish;
  final VoidCallback onSave;
  final ValueChanged<String> onIntensityChanged;

  const SessionFooter({
    super.key,
    required this.showConfirmation,
    required this.saving,
    required this.elapsedLabel,
    required this.doneCount,
    required this.totalVolume,
    required this.intensity,
    required this.notesController,
    required this.onBeginFinish,
    required this.onCancelFinish,
    required this.onSave,
    required this.onIntensityChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (!showConfirmation) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ApexColors.surface,
          border: Border(top: BorderSide(color: ApexColors.border)),
        ),
        child: ApexButton(
          text: 'Finish workout',
          icon: Icons.flag_rounded,
          onPressed: onBeginFinish,
          full: true,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ApexColors.card,
        border: Border(top: BorderSide(color: ApexColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Save this session?',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w800,
              fontSize: 12,
              color: ApexColors.t1,
            ),
          ),
          Text(
            '$elapsedLabel · $doneCount sets · ${totalVolume}kg',
            style: const TextStyle(color: ApexColors.t2, fontSize: 10),
          ),
          const SizedBox(height: 9),
          Text(
            'INTENSITY',
            style: GoogleFonts.inter(
              fontSize: 10,
              color: ApexColors.t2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _IntensityChip(
                label: 'Light',
                value: 'light',
                active: intensity == 'light',
                color: ApexColors.accentSoft,
                onTap: onIntensityChanged,
              ),
              _IntensityChip(
                label: 'Moderate',
                value: 'moderate',
                active: intensity == 'moderate',
                color: ApexColors.blue,
                onTap: onIntensityChanged,
              ),
              _IntensityChip(
                label: 'Heavy',
                value: 'heavy',
                active: intensity == 'heavy',
                color: ApexColors.orange,
                onTap: onIntensityChanged,
              ),
            ],
          ),
          const SizedBox(height: 9),
          TextField(
            controller: notesController,
            style: GoogleFonts.inter(fontSize: 13, color: ApexColors.t1),
            decoration: const InputDecoration(hintText: 'Session notes'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ApexButton(
                  text: 'Back',
                  onPressed: onCancelFinish,
                  outline: true,
                  sm: true,
                  full: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ApexButton(
                  text: 'Save and exit',
                  icon: Icons.check_rounded,
                  onPressed: onSave,
                  full: true,
                  loading: saving,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IntensityChip extends StatelessWidget {
  final String label;
  final String value;
  final bool active;
  final Color color;
  final ValueChanged<String> onTap;

  const _IntensityChip({
    required this.label,
    required this.value,
    required this.active,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(value),
        child: Container(
          margin: const EdgeInsets.only(right: 6),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: active ? color.withAlpha(32) : ApexColors.surface,
            border: Border.all(
              color: active ? color : ApexColors.border,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active ? color : ApexColors.t2,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

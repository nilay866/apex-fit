import 'package:flutter/material.dart';
import 'package:apex_ai/constants/colors.dart';
import 'package:apex_ai/services/supabase_service.dart';
import 'package:google_fonts/google_fonts.dart';

class MoodCheckinWidget extends StatefulWidget {
  final int initialMood;
  final ValueChanged<int>? onMoodChanged;

  const MoodCheckinWidget({
    super.key,
    this.initialMood = 3,
    this.onMoodChanged,
  });

  @override
  State<MoodCheckinWidget> createState() => _MoodCheckinWidgetState();
}

class _MoodCheckinWidgetState extends State<MoodCheckinWidget> {
  int _selected = 3;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialMood;
  }

  static const _emojis = ['😔', '😕', '😐', '🙂', '😄'];
  static const _labels = ['Low', 'Below avg', 'Okay', 'Good', 'Great'];

  Future<void> _save(int mood) async {
    setState(() {
      _selected = mood;
      _saved = false;
    });
    try {
      final uid = SupabaseService.currentUser?.id;
      if (uid != null) {
        await SupabaseService.saveMoodToday(uid, mood);
        if (mounted) setState(() => _saved = true);
        widget.onMoodChanged?.call(mood);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ApexColors.cardAlt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ApexColors.borderStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'How are you feeling?',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: ApexColors.t1,
                ),
              ),
              if (_saved)
                Text(
                  '✓ Saved',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: ApexColors.accentSoft,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(5, (i) {
              final mood = i + 1;
              final isSelected = _selected == mood;
              return GestureDetector(
                onTap: () => _save(mood),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? ApexColors.accentSoft.withAlpha(30)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    border: isSelected
                        ? Border.all(color: ApexColors.accentSoft.withAlpha(80))
                        : null,
                  ),
                  child: Column(
                    children: [
                      Text(
                        _emojis[i],
                        style: TextStyle(fontSize: isSelected ? 28 : 22),
                      ),
                      if (isSelected)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            _labels[i],
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              color: ApexColors.accentSoft,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

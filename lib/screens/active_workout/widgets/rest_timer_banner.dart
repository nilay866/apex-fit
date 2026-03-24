import 'package:flutter/material.dart';
import '../../../constants/colors.dart';
import '../../../constants/theme.dart';

class RestTimerBanner extends StatelessWidget {
  final String formattedTime;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final VoidCallback onSkip;

  const RestTimerBanner({
    super.key,
    required this.formattedTime,
    required this.onDecrease,
    required this.onIncrease,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: ApexColors.blue.withAlpha(24),
        border: Border(bottom: BorderSide(color: ApexColors.blue, width: 2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Rest timer',
                style: TextStyle(
                  color: ApexColors.blue,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _ActionChip(label: '-5s', onTap: onDecrease),
                  const SizedBox(width: 8),
                  _ActionChip(label: '+15s', onTap: onIncrease),
                ],
              ),
            ],
          ),
          Text(
            formattedTime,
            style: ApexTheme.mono(size: 24, color: ApexColors.blue),
          ),
          _ActionChip(label: 'Skip', onTap: onSkip),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ActionChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: ApexColors.blue.withAlpha(40),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: ApexColors.blue,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

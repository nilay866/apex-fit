import 'package:flutter/material.dart';
import '../../../constants/colors.dart';

class SmartTipBanner extends StatelessWidget {
  final String message;

  const SmartTipBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ApexColors.accent.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ApexColors.accent.withAlpha(50)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.psychology_rounded,
            color: ApexColors.accent,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: ApexColors.t1,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

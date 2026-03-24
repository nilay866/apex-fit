import 'package:flutter/material.dart';
import '../constants/colors.dart';

class MiniChart extends StatelessWidget {
  final List<double> values;
  final Color color;
  final double height;

  const MiniChart({
    super.key,
    required this.values,
    this.color = ApexColors.accentSoft,
    this.height = 50,
  });

  @override
  Widget build(BuildContext context) {
    final maxVal = values.fold<double>(1, (a, b) => b > a ? b : a);
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: values.map((v) {
          final pct = maxVal > 0 ? (v / maxVal) : 0.0;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ColoredBox(
                  color: ApexColors.surface,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: FractionallySizedBox(
                      heightFactor: pct > 0 ? pct.clamp(0.06, 1.0) : 0.08,
                      widthFactor: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: v > 0
                              ? LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [color, color.withAlpha(120)],
                                )
                              : null,
                          color: v > 0 ? null : ApexColors.border,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

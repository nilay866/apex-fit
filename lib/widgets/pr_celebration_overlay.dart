import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:apex_ai/constants/colors.dart';
import 'package:google_fonts/google_fonts.dart';

class PrCelebrationOverlay extends StatefulWidget {
  final String exerciseName;
  final double weightKg;
  final int reps;
  final VoidCallback onDismiss;

  const PrCelebrationOverlay({
    super.key,
    required this.exerciseName,
    required this.weightKg,
    required this.reps,
    required this.onDismiss,
  });

  @override
  State<PrCelebrationOverlay> createState() => _PrCelebrationOverlayState();
}

class _PrCelebrationOverlayState extends State<PrCelebrationOverlay> {
  late ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 3));
    _confetti.play();
    // Auto-dismiss after 5s
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withAlpha(200),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Confetti
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 30,
              colors: const [
                ApexColors.accentSoft,
                Colors.white,
                Color(0xFFFFD600),
                Color(0xFF3D9BFF),
              ],
            ),
          ),
          // Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: ApexColors.cardAlt,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: ApexColors.accentSoft.withAlpha(80),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: ApexColors.accentSoft.withAlpha(40),
                    blurRadius: 40,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏆', style: TextStyle(fontSize: 52)),
                  const SizedBox(height: 12),
                  Text(
                    'NEW PERSONAL RECORD',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: ApexColors.accentSoft,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.exerciseName,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: ApexColors.t1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${widget.weightKg}kg × ${widget.reps} reps',
                    style: GoogleFonts.inter(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: ApexColors.accentSoft,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: widget.onDismiss,
                          child: Text(
                            'Keep Going',
                            style: GoogleFonts.inter(
                              color: ApexColors.t2,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

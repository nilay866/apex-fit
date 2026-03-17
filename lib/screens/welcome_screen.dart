import 'package:flutter/material.dart';
import 'package:apex_ai/constants/colors.dart';
import 'package:apex_ai/widgets/apex_button.dart';
import 'package:apex_ai/widgets/apex_orb_logo.dart';
import 'package:google_fonts/google_fonts.dart';

class WelcomeScreen extends StatelessWidget {
  final VoidCallback onGetStarted;
  final VoidCallback onLogin;

  const WelcomeScreen({
    super.key,
    required this.onGetStarted,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ApexColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              // TOP ILLUSTRATION AREA
              Expanded(
                flex: 3,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const ApexOrbLogo(size: 100, label: 'A'),
                    const SizedBox(height: 32),
                    Text(
                      'Train Smarter.\nNot Harder.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: ApexColors.t1,
                        letterSpacing: -1.5,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'AI-powered workouts, nutrition, and coaching — '
                      'personalized to your body, goals, and recovery.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: ApexColors.t2,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Feature pills
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        '🏋️ Smart Workouts',
                        '🥗 Nutrition AI',
                        '🔥 Streak Tracking',
                        '📊 Progress Analytics',
                        '🤖 AI Coach',
                        '👥 Community',
                      ]
                          .map(
                            (f) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: ApexColors.cardAlt,
                                borderRadius: BorderRadius.circular(100),
                                border:
                                    Border.all(color: ApexColors.borderStrong),
                              ),
                              child: Text(
                                f,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: ApexColors.t2,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),

              // BOTTOM ACTIONS — thumb zone
              Expanded(
                flex: 1,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ApexButton(
                      text: "Get Started — It's Free",
                      onPressed: onGetStarted,
                      full: true,
                    ),
                    const SizedBox(height: 12),
                    ApexButton(
                      text: 'I already have an account',
                      onPressed: onLogin,
                      tone: ApexButtonTone.outline,
                      color: ApexColors.t2,
                      full: true,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

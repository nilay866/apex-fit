import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/colors.dart';
import '../repositories/auth_repository.dart';
import '../services/supabase_service.dart';
import '../widgets/apex_backdrop.dart';
import '../widgets/apex_button.dart';
import '../widgets/apex_card.dart';
import '../widgets/apex_orb_logo.dart';

class AuthScreen extends StatefulWidget {
  final VoidCallback onAuth;

  const AuthScreen({super.key, required this.onAuth});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLogin = true;
  final _nameC = TextEditingController();
  final _emailC = TextEditingController();
  final _pwC = TextEditingController();
  String _goal = 'Build Muscle';
  int _age = 25;
  int _level = 5;
  bool _loading = false;
  String _err = '';
  String _info = '';

  static const _goals = [
    'Build Muscle',
    'Lose Fat',
    'Calisthenics Skills',
    'Strength & Power',
    'General Fitness',
  ];

  static const _goalIcons = <String, IconData>{
    'Build Muscle': Icons.fitness_center_rounded,
    'Lose Fat': Icons.local_fire_department_rounded,
    'Calisthenics Skills': Icons.sports_gymnastics_rounded,
    'Strength & Power': Icons.flash_on_rounded,
    'General Fitness': Icons.favorite_rounded,
  };

  Future<void> _submit() async {
    if (_emailC.text.trim().isEmpty || _pwC.text.isEmpty) {
      setState(() => _err = 'Enter email and password.');
      return;
    }
    if (!_isLogin && _nameC.text.trim().isEmpty) {
      setState(() => _err = 'Name required.');
      return;
    }
    if (_pwC.text.length < 6) {
      setState(() => _err = 'Password must be 6+ characters.');
      return;
    }

    setState(() {
      _loading = true;
      _err = '';
      _info = '';
    });

    try {
      if (_isLogin) {
        await authRepository.signIn(_emailC.text.trim(), _pwC.text);
        widget.onAuth();
      } else {
        final res = await authRepository.signUp(
          _emailC.text.trim(),
          _pwC.text,
          _nameC.text.trim(),
        );
        if (res.user != null) {
          try {
            await SupabaseService.updateProfile(res.user!.id, {
              'goal': _goal,
              'name': _nameC.text.trim(),
              'age': _age,
              'fitness_level': _level,
            });
          } catch (_) {}
          if (res.session != null) {
            widget.onAuth();
          } else {
            setState(() {
              _info =
                  'Check your inbox for the confirmation email, then sign in.';
              _isLogin = true;
            });
          }
        } else {
          setState(() {
            _info =
                'Check your inbox for the confirmation email, then sign in.';
            _isLogin = true;
          });
        }
      }
    } catch (e) {
      var message = e.toString();
      if (message.contains('Invalid login')) {
        message = 'Wrong email or password. If you\'re new, create an account first.';
      } else if (message.contains('not confirmed')) {
        message = 'Confirm your email first.';
      } else if (message.contains('already registered')) {
        message = 'Email already registered. Try signing in.';
      }
      setState(() => _err = message);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _nameC.dispose();
    _emailC.dispose();
    _pwC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ApexColors.bg,
      body: ApexBackdrop(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    const ApexOrbLogo(size: 96, label: 'APEX'),
                    const SizedBox(height: 20),
                    Text(
                      'APEX AI',
                      style: GoogleFonts.inter(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        color: ApexColors.t1,
                        letterSpacing: -1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isLogin
                          ? 'Sign in to your training workspace.'
                          : 'Create your athlete profile and sync with your app.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 22),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: ApexColors.surface,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: ApexColors.border),
                      ),
                      child: Row(
                        children: [
                          _toggleTab('Sign in', _isLogin, () {
                            setState(() {
                              _isLogin = true;
                              _err = '';
                              _info = '';
                            });
                          }),
                          _toggleTab('Create account', !_isLogin, () {
                            setState(() {
                              _isLogin = false;
                              _err = '';
                              _info = '';
                            });
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (_info.isNotEmpty) _messageCard(_info, ApexColors.blue),
                    if (_err.isNotEmpty) ...[
                      if (_info.isNotEmpty) const SizedBox(height: 12),
                      _messageCard(_err, ApexColors.red),
                    ],
                    if (_info.isNotEmpty || _err.isNotEmpty)
                      const SizedBox(height: 12),
                    ApexCard(
                      glow: true,
                      glowColor: ApexColors.accentSoft,
                      floating: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isLogin ? 'Welcome back' : 'Your details',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isLogin
                                ? 'Use your existing account to continue on any device.'
                                : 'These details create the base profile saved in your Supabase project.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 18),
                          if (!_isLogin) ...[
                            _fieldLabel('Full name'),
                            const SizedBox(height: 6),
                            TextField(
                              key: const ValueKey('auth_name_field'),
                              controller: _nameC,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: ApexColors.t1,
                              ),
                              decoration: const InputDecoration(
                                hintText: 'Nilay Chavhan',
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],
                          _fieldLabel('Email'),
                          const SizedBox(height: 6),
                          TextField(
                            key: const ValueKey('auth_email_field'),
                            controller: _emailC,
                            keyboardType: TextInputType.emailAddress,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: ApexColors.t1,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'you@example.com',
                            ),
                          ),
                          const SizedBox(height: 14),
                          _fieldLabel('Password'),
                          const SizedBox(height: 6),
                          TextField(
                            key: const ValueKey('auth_password_field'),
                            controller: _pwC,
                            obscureText: true,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: ApexColors.t1,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Minimum 6 characters',
                            ),
                          ),
                          if (!_isLogin) ...[
                            const SizedBox(height: 16),
                            _fieldLabel('Primary goal'),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 108,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: _goals.map((goal) {
                                  final selected = _goal == goal;
                                  return GestureDetector(
                                    onTap: () => setState(() => _goal = goal),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      margin: const EdgeInsets.only(right: 12),
                                      padding: const EdgeInsets.all(12),
                                      width: 110,
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? ApexColors.accentDim
                                            : ApexColors.surface,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: selected
                                              ? ApexColors.accent
                                              : ApexColors.border,
                                          width: selected ? 2 : 1,
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            _goalIcons[goal] ?? Icons.flag_circle,
                                            size: 24,
                                            color: selected
                                                ? ApexColors.accent
                                                : ApexColors.t3,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            goal,
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.inter(
                                              color: selected
                                                  ? ApexColors.t1
                                                  : ApexColors.t2,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 24),
                            _fieldLabel('Age ($_age)'),
                            Slider(
                              value: _age.toDouble(),
                              min: 16,
                              max: 80,
                              divisions: 64,
                              activeColor: ApexColors.accent,
                              inactiveColor: ApexColors.borderStrong,
                              onChanged: (v) =>
                                  setState(() => _age = v.toInt()),
                            ),
                            const SizedBox(height: 16),
                            _fieldLabel('Fitness Level ($_level/10)'),
                            Slider(
                              value: _level.toDouble(),
                              min: 1,
                              max: 10,
                              divisions: 9,
                              activeColor: ApexColors.accent,
                              inactiveColor: ApexColors.borderStrong,
                              onChanged: (v) =>
                                  setState(() => _level = v.toInt()),
                            ),
                          ],
                          const SizedBox(height: 18),
                          ApexButton(
                            key: const ValueKey('auth_submit_button'),
                            text: _isLogin
                                ? 'Sign in with Email'
                                : 'Create account',
                            onPressed: _submit,
                            full: true,
                            loading: _loading,
                          ),
                          if (_isLogin) ...[
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 1,
                                    color: ApexColors.border,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                  child: Text(
                                    'OR',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: ApexColors.t3,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Container(
                                    height: 1,
                                    color: ApexColors.border,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            ApexButton(
                              text: 'Continue with Google',
                              icon: Icons.g_mobiledata_rounded,
                              tone: ApexButtonTone.outline,
                              color: ApexColors.t1,
                              full: true,
                              onPressed: () => SupabaseService.signInWithOAuth(
                                OAuthProvider.google,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ApexButton(
                              text: 'Continue with Apple',
                              icon: Icons.apple_rounded,
                              tone: ApexButtonTone.outline,
                              color: ApexColors.t1,
                              full: true,
                              onPressed: () => SupabaseService.signInWithOAuth(
                                OAuthProvider.apple,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (!_isLogin) ...[
                      const SizedBox(height: 12),
                      Text(
                        'If email confirmation is enabled in Supabase, confirm your inbox before signing in.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _toggleTab(String text, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: active ? ApexColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: active ? ApexColors.ink : ApexColors.t2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.inter(
        fontSize: 10,
        color: ApexColors.t3,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _messageCard(String message, Color color) {
    return ApexCard(
      floating: false,
      glow: true,
      glowColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                color: ApexColors.t1,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

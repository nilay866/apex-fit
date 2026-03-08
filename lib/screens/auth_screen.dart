import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';
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
        await SupabaseService.signIn(_emailC.text.trim(), _pwC.text);
        widget.onAuth();
      } else {
        final res = await SupabaseService.signUp(
          _emailC.text.trim(),
          _pwC.text,
          _nameC.text.trim(),
        );
        if (res.user != null) {
          try {
            await SupabaseService.updateProfile(res.user!.id, {
              'goal': _goal,
              'name': _nameC.text.trim(),
            });
          } catch (_) {}
          if (res.session != null) {
            widget.onAuth();
          } else {
            setState(() {
              _info = 'Check your inbox for the confirmation email, then sign in.';
              _isLogin = true;
            });
          }
        } else {
          setState(() {
            _info = 'Check your inbox for the confirmation email, then sign in.';
            _isLogin = true;
          });
        }
      }
    } catch (e) {
      var message = e.toString();
      if (message.contains('Invalid login')) {
        message = 'Wrong email or password.';
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
                      style: GoogleFonts.spaceGrotesk(
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
                    if (_info.isNotEmpty || _err.isNotEmpty) const SizedBox(height: 12),
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
                              controller: _nameC,
                              style: GoogleFonts.spaceGrotesk(fontSize: 14, color: ApexColors.t1),
                              decoration: const InputDecoration(hintText: 'Nilay Chavhan'),
                            ),
                            const SizedBox(height: 14),
                          ],
                          _fieldLabel('Email'),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _emailC,
                            keyboardType: TextInputType.emailAddress,
                            style: GoogleFonts.spaceGrotesk(fontSize: 14, color: ApexColors.t1),
                            decoration: const InputDecoration(hintText: 'you@example.com'),
                          ),
                          const SizedBox(height: 14),
                          _fieldLabel('Password'),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _pwC,
                            obscureText: true,
                            style: GoogleFonts.spaceGrotesk(fontSize: 14, color: ApexColors.t1),
                            decoration: const InputDecoration(hintText: 'Minimum 6 characters'),
                          ),
                          if (!_isLogin) ...[
                            const SizedBox(height: 16),
                            _fieldLabel('Primary goal'),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _goals.map((goal) {
                                final selected = _goal == goal;
                                return GestureDetector(
                                  onTap: () => setState(() => _goal = goal),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                    decoration: BoxDecoration(
                                      color: selected ? ApexColors.accentDim : ApexColors.surface,
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: selected ? ApexColors.accentSoft : ApexColors.border,
                                      ),
                                    ),
                                    child: Text(
                                      goal,
                                      style: GoogleFonts.spaceGrotesk(
                                        color: selected ? ApexColors.t1 : ApexColors.t2,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                          const SizedBox(height: 18),
                          ApexButton(
                            text: _isLogin ? 'Sign in' : 'Create account',
                            onPressed: _submit,
                            full: true,
                            loading: _loading,
                          ),
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
            style: GoogleFonts.spaceGrotesk(
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
      style: GoogleFonts.spaceGrotesk(
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
              style: GoogleFonts.spaceGrotesk(
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

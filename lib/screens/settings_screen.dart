import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apex_ai/constants/colors.dart';
import 'package:apex_ai/widgets/apex_card.dart';
import 'package:apex_ai/widgets/apex_button.dart';
import 'package:apex_ai/services/supabase_service.dart';
import 'package:apex_ai/services/cache_service.dart';
import 'package:google_fonts/google_fonts.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifWorkout = true;
  bool _notifNutrition = true;
  bool _notifSocial = false;
  bool _notifStreak = true;
  String _units = 'kg';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final units = prefs.getString('apex_units') ?? 'kg';
      if (mounted) setState(() => _units = units);
    } catch (_) {}
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('apex_units', _units);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved'),
            backgroundColor: ApexColors.accent,
          ),
        );
      }
    } catch (_) {}
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ApexColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Sign out?',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: ApexColors.t1,
          ),
        ),
        content: Text(
          'You will be returned to the login screen.',
          style: GoogleFonts.inter(fontSize: 13, color: ApexColors.t2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: ApexColors.t2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Sign out',
              style: GoogleFonts.inter(
                color: ApexColors.red,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        // Clear cached data before signing out
        CacheService().invalidate(null);
        await SupabaseService.signOut();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sign out failed: ${SupabaseService.describeError(e)}'),
              backgroundColor: ApexColors.red,
            ),
          );
        }
      }
    }
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature — coming soon'),
        backgroundColor: ApexColors.surface,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ApexColors.bg,
      appBar: AppBar(
        backgroundColor: ApexColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: ApexColors.t1, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Settings',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: ApexColors.t1,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          // UNITS
          _sectionHeader('Preferences'),
          ApexCard(
            child: Column(
              children: [
                _settingRow(
                  icon: Icons.fitness_center_rounded,
                  iconColor: ApexColors.accent,
                  title: 'Weight Units',
                  subtitle: 'Choose your preferred unit',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: ['kg', 'lbs'].map((u) {
                      final sel = _units == u;
                      return GestureDetector(
                        onTap: () => setState(() => _units = u),
                        child: Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: sel
                                ? ApexColors.accent.withAlpha(30)
                                : ApexColors.cardAlt,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: sel
                                  ? ApexColors.accent
                                  : ApexColors.borderStrong,
                            ),
                          ),
                          child: Text(
                            u,
                            style: TextStyle(
                              color: sel ? ApexColors.accent : ApexColors.t2,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          _sectionHeader('Notifications'),
          ApexCard(
            child: Column(
              children: [
                _toggleRow(
                  'Workout reminders',
                  'Daily push to start your session',
                  Icons.notifications_active_rounded,
                  ApexColors.blue,
                  _notifWorkout,
                  (v) => setState(() => _notifWorkout = v),
                ),
                _divider(),
                _toggleRow(
                  'Nutrition alerts',
                  'Remind to log meals',
                  Icons.restaurant_rounded,
                  ApexColors.orange,
                  _notifNutrition,
                  (v) => setState(() => _notifNutrition = v),
                ),
                _divider(),
                _toggleRow(
                  'Streak protection',
                  'Alert before streak breaks',
                  Icons.local_fire_department_rounded,
                  ApexColors.yellow,
                  _notifStreak,
                  (v) => setState(() => _notifStreak = v),
                ),
                _divider(),
                _toggleRow(
                  'Social activity',
                  'Friend workouts and reactions',
                  Icons.people_rounded,
                  ApexColors.purple,
                  _notifSocial,
                  (v) => setState(() => _notifSocial = v),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          _sectionHeader('Integrations'),
          ApexCard(
            child: Column(
              children: [
                _linkRow(
                  'Apple Health',
                  'Sync steps, sleep & HRV',
                  Icons.favorite_rounded,
                  ApexColors.red,
                  onTap: () => _showComingSoon('Apple Health sync'),
                ),
                _divider(),
                _linkRow(
                  'Google Fit',
                  'Sync activity data',
                  Icons.directions_run_rounded,
                  ApexColors.blue,
                  onTap: () => _showComingSoon('Google Fit sync'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          _sectionHeader('Account'),
          ApexCard(
            child: Column(
              children: [
                _linkRow(
                  'Edit Profile',
                  'Name, photo, bio',
                  Icons.person_rounded,
                  ApexColors.accent,
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                _divider(),
                _linkRow(
                  'Privacy',
                  'Who can see your activity',
                  Icons.lock_rounded,
                  ApexColors.t2,
                  onTap: () => _showComingSoon('Privacy settings'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          ApexButton(
            text: 'Save Settings',
            onPressed: _save,
            full: true,
            loading: _saving,
          ),
          const SizedBox(height: 12),
          ApexButton(
            text: 'Sign Out',
            onPressed: _signOut,
            tone: ApexButtonTone.outline,
            color: ApexColors.red,
            full: true,
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            color: ApexColors.t3,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      );

  Widget _divider() => const Divider(color: ApexColors.border, height: 1);

  Widget _settingRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: ApexColors.t1)),
                Text(subtitle,
                    style:
                        const TextStyle(fontSize: 11, color: ApexColors.t3)),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  Widget _toggleRow(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return _settingRow(
      icon: icon,
      iconColor: color,
      title: title,
      subtitle: subtitle,
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeTrackColor: ApexColors.accent,
      ),
    );
  }

  Widget _linkRow(
    String title,
    String subtitle,
    IconData icon,
    Color color, {
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: _settingRow(
        icon: icon,
        iconColor: color,
        title: title,
        subtitle: subtitle,
        trailing: const Icon(Icons.chevron_right_rounded,
            color: ApexColors.t3, size: 20),
      ),
    );
  }
}

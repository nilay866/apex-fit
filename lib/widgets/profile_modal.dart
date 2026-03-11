import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import 'package:image_picker/image_picker.dart';
import '../services/supabase_service.dart';
import '../widgets/apex_button.dart';
import '../widgets/apex_orb_logo.dart';

@Deprecated('Use ProfileScreen instead.')
class ProfileModal extends StatelessWidget {
  final Map<String, dynamic>? profile;
  final VoidCallback onSignOut;
  final VoidCallback onSaved;

  const ProfileModal({
    super.key,
    this.profile,
    required this.onSignOut,
    required this.onSaved,
  });

  @override
  Widget build(BuildContext context) {
    return ProfileScreen(
      profile: profile,
      onSignOut: onSignOut,
      onSaved: onSaved,
    );
  }
}

class ProfileScreen extends StatefulWidget {
  final Map<String, dynamic>? profile;
  final VoidCallback onSignOut;
  final VoidCallback onSaved;

  const ProfileScreen({
    super.key,
    this.profile,
    required this.onSignOut,
    required this.onSaved,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _nameC;
  late TextEditingController _weightC;
  late TextEditingController _heightC;
  late TextEditingController _calGoalC;
  late TextEditingController _waterGoalC;
  late String _goal;
  String? _avatarData;
  bool _loading = false;
  bool _saved = false;

  static const _goals = [
    'Build Muscle',
    'Lose Fat',
    'Calisthenics Skills',
    'Strength & Power',
    'General Fitness',
  ];

  @override
  void initState() {
    super.initState();
    _nameC = TextEditingController(text: widget.profile?['name']?.toString() ?? '');
    _weightC = TextEditingController(text: widget.profile?['weight_kg']?.toString() ?? '');
    _heightC = TextEditingController(text: widget.profile?['height_cm']?.toString() ?? '');
    _calGoalC = TextEditingController(text: (widget.profile?['calorie_goal'] ?? 2000).toString());
    _waterGoalC = TextEditingController(text: (widget.profile?['water_goal_ml'] ?? 2500).toString());
    _goal = widget.profile?['goal']?.toString() ?? 'Build Muscle';
    _avatarData = widget.profile?['avatar_data']?.toString();

    _nameC.addListener(_handlePreviewChange);
    _weightC.addListener(_handlePreviewChange);
    _heightC.addListener(_handlePreviewChange);
  }

  void _handlePreviewChange() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _pickAvatar(ImageSource source, BuildContext sheetContext) async {
    Navigator.pop(sheetContext);
    Haptics.vibrate(HapticsType.light);
    final picker = ImagePicker();
    try {
      final file = await picker.pickImage(
        source: source,
        maxWidth: 1200,
        imageQuality: 85,
      );
      if (file == null) return;

      final avatarData = await _encodeAvatar(file);
      if (!mounted) return;
      setState(() {
        _avatarData = avatarData;
      });
      // Auto-save the photo immediately for better UX
      await _save();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Photo update failed: ${SupabaseService.describeError(e)}'),
          backgroundColor: _ProfilePalette.text,
        ),
      );
    }
  }

  Future<String> _encodeAvatar(XFile file) async {
    final compressedBytes = await FlutterImageCompress.compressWithFile(
      file.path,
      quality: 60,
      minWidth: 300,
      minHeight: 300,
      format: CompressFormat.jpeg,
    );
    final bytes = compressedBytes ?? await file.readAsBytes();
    return 'data:image/jpeg;base64,${base64Encode(bytes)}';
  }

  Future<void> _showAvatarOptions() async {
    Haptics.vibrate(HapticsType.light);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _ProfilePalette.sheet.withAlpha(210), // Reduced opacity for blur
                border: Border.all(color: _ProfilePalette.border),
                boxShadow: const [
                  BoxShadow(
                    color: _ProfilePalette.shadow,
                    blurRadius: 24,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: _ProfilePalette.hint,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Update profile photo',
                      style: _ProfileText.title,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Use camera, choose from library, or clear the current image.',
                      textAlign: TextAlign.center,
                      style: _ProfileText.body,
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: ApexButton(
                            text: 'Camera',
                            icon: Icons.camera_alt_outlined,
                            onPressed: () => _pickAvatar(ImageSource.camera, sheetContext),
                            tone: ApexButtonTone.outline,
                            color: _ProfilePalette.text,
                            full: true,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ApexButton(
                            text: 'Gallery',
                            icon: Icons.photo_library_outlined,
                            onPressed: () => _pickAvatar(ImageSource.gallery, sheetContext),
                            tone: ApexButtonTone.outline,
                            color: _ProfilePalette.text,
                            full: true,
                          ),
                        ),
                      ],
                    ),
                    if (_avatarData != null) ...[
                      const SizedBox(height: 10),
                      ApexButton(
                        text: 'Remove photo',
                        icon: Icons.delete_outline_rounded,
                        onPressed: () {
                          Haptics.vibrate(HapticsType.medium);
                          Navigator.pop(sheetContext);
                          setState(() => _avatarData = null);
                        },
                        tone: ApexButtonTone.soft,
                        color: _ProfilePalette.destructive,
                        full: true,
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

  Future<void> _save() async {
    Haptics.vibrate(HapticsType.medium);
    setState(() => _loading = true);
    
    // Clear focus natively when saving
    FocusScope.of(context).unfocus();
    
    try {
      final data = <String, dynamic>{
        'name': _nameC.text.trim(),
        'goal': _goal,
        'calorie_goal': int.tryParse(_calGoalC.text) ?? 2000,
        'water_goal_ml': int.tryParse(_waterGoalC.text) ?? 2500,
        'avatar_data': _avatarData,
      };

      final weight = double.tryParse(_weightC.text);
      if (weight != null) {
        data['weight_kg'] = weight;
      }

      final height = double.tryParse(_heightC.text);
      if (height != null) {
        data['height_cm'] = height;
      }

      await SupabaseService.updateProfile(SupabaseService.currentUser!.id, data);
      
      Haptics.vibrate(HapticsType.success);
      if (!mounted) return;
      setState(() => _saved = true);
      widget.onSaved();
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() => _saved = false);
        }
      });
    } catch (e) {
      Haptics.vibrate(HapticsType.error);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(SupabaseService.describeError(e)),
          backgroundColor: _ProfilePalette.text,
        ),
      );
    }
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  void _signOut() {
    Haptics.vibrate(HapticsType.medium);
    Navigator.of(context).pop();
    widget.onSignOut();
  }



  @override
  Widget build(BuildContext context) {
    final email = SupabaseService.currentUser?.email ?? '';
    final displayName = _nameC.text.trim().isNotEmpty ? _nameC.text.trim() : 'Athlete';
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(), // Tapping anywhere dismisses keyboard
      child: Theme(
        data: Theme.of(context).copyWith(
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: _ProfilePalette.field,
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(22),
              borderSide: const BorderSide(color: _ProfilePalette.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(22),
              borderSide: const BorderSide(color: _ProfilePalette.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(22),
              borderSide: const BorderSide(color: _ProfilePalette.focus, width: 1.2),
            ),
            hintStyle: _ProfileText.inputHint,
            labelStyle: _ProfileText.label,
          ),
          snackBarTheme: SnackBarThemeData(
            backgroundColor: _ProfilePalette.text,
            contentTextStyle: _ProfileText.onDark,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
        ),
        child: Scaffold(
          backgroundColor: _ProfilePalette.base,
          // Removed resizeToAvoidBottomInset so the button at bottom stays floating while keyboard shows,
          // or we handle scrolling explicitly. Let's keep true but handle list padding.
          resizeToAvoidBottomInset: true,
          body: Stack(
            children: [
              const Positioned.fill(child: _ProfileGymBackdrop()),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withAlpha(90),
                        Colors.white.withAlpha(170),
                        const Color(0xFFF7F8FB),
                      ],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                      child: Row(
                        children: [
                          _iconShell(
                            icon: Icons.arrow_back_rounded,
                            onTap: () {
                              Haptics.vibrate(HapticsType.light);
                              Navigator.of(context).pop();
                            },
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Profile', style: _ProfileText.pageTitle),
                                const SizedBox(height: 4),
                                Text(
                                  'Gym profile synced.',
                                  style: _ProfileText.caption,
                                ),
                              ],
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: _saved ? _ProfilePalette.successSoft : _ProfilePalette.surfaceStrong,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: _saved ? _ProfilePalette.success : _ProfilePalette.border,
                              ),
                            ),
                            child: Text(
                              _saved ? 'Synced' : 'Gym profile',
                              style: _saved ? _ProfileText.success : _ProfileText.captionStrong,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _buildScrollableContent(
                        displayName: displayName, 
                        email: email, 
                        bottomInset: bottomInset
                      ),
                    ),
                    SafeArea(
                      top: false,
                      // Remove bottomInset padding from here because Scaffold handles AvoidBottomInset 
                      minimum: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: _ProfilePalette.surfaceStrong,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: _ProfilePalette.border),
                          boxShadow: const [
                            BoxShadow(
                              color: _ProfilePalette.shadow,
                              blurRadius: 18,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: ApexButton(
                            text: _saved ? 'Saved' : 'Save changes',
                            onPressed: _save,
                            color: _ProfilePalette.text,
                            full: true,
                            loading: _loading,
                            icon: _saved ? Icons.check_rounded : Icons.save_outlined,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScrollableContent({
    required String displayName,
    required String email,
    required double bottomInset,
  }) {
    // Single consolidated view
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 80),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        // Avatar Header section
        Center(
          child: Column(
            children: [
              ApexOrbLogo(
                size: 116,
                label: displayName,
                imageData: _avatarData,
                onTap: _showAvatarOptions,
                showEditBadge: true,
                badgeIcon: Icons.photo_camera_back_outlined,
                variant: ApexOrbVariant.light,
              ),
              const SizedBox(height: 16),
              Text(displayName, style: _ProfileText.heroName),
              const SizedBox(height: 6),
              Text(email, style: _ProfileText.body),
              const SizedBox(height: 24),
            ],
          ),
        ),
        
        // Personal Details Fields
        Text('Personal Details', style: _ProfileText.sectionTitle),
        const SizedBox(height: 12),
        _surfacePanel(
          child: Column(
            children: [
              _field('Name', _nameC, 'Your name'),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _field('Weight (kg)', _weightC, '80', number: true)),
                  const SizedBox(width: 12),
                  Expanded(child: _field('Height (cm)', _heightC, '180', number: true)),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _field('Calorie goal', _calGoalC, '2000', number: true)),
                  const SizedBox(width: 12),
                  Expanded(child: _field('Water goal (ml)', _waterGoalC, '2500', number: true)),
                ],
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 32),
        
        // Primary Goal Section
        Text('Primary focus', style: _ProfileText.sectionTitle),
        const SizedBox(height: 8),
        Text(
          'Set the goal your dashboard and coach should prioritize.',
          style: _ProfileText.body,
        ),
        const SizedBox(height: 16),
        _surfacePanel(
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _goals.map((goal) {
              final selected = _goal == goal;
              return GestureDetector(
                onTap: () {
                  Haptics.vibrate(HapticsType.selection);
                  setState(() => _goal = goal);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: selected ? _ProfilePalette.goalSelected : _ProfilePalette.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected ? _ProfilePalette.focus : _ProfilePalette.border,
                    ),
                    boxShadow: selected
                        ? const [
                            BoxShadow(
                              color: _ProfilePalette.highlightShadow,
                              blurRadius: 14,
                              offset: Offset(0, 8),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (selected) ...[
                        Container(
                          width: 18,
                          height: 18,
                          decoration: const BoxDecoration(
                            color: _ProfilePalette.text,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check_rounded, size: 12, color: Colors.white),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        goal,
                        style: selected ? _ProfileText.goalActive : _ProfileText.goal,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        
        const SizedBox(height: 32),
        
        // Account Status
        Text('Status', style: _ProfileText.sectionTitle),
        const SizedBox(height: 12),
        _readOnlyTile(
          icon: Icons.cloud_done_rounded,
          label: 'Sync info',
          value: 'All changes sync automatically',
        ),
        const SizedBox(height: 24),
        
        // Sign out button
        ApexButton(
          text: 'Sign out',
          onPressed: _signOut,
          tone: ApexButtonTone.soft,
          color: _ProfilePalette.destructive,
          full: true,
          icon: Icons.logout_rounded,
        ),
      ],
    );
  }

  Widget _iconShell({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _ProfilePalette.surfaceStrong,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _ProfilePalette.border),
          ),
          child: Icon(icon, size: 20, color: _ProfilePalette.text),
        ),
      ),
    );
  }

  Widget _surfacePanel({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _ProfilePalette.surfaceStrong,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _ProfilePalette.border),
        boxShadow: const [
          BoxShadow(
            color: _ProfilePalette.shadow,
            blurRadius: 22,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _field(
    String label,
    TextEditingController controller,
    String hint, {
    bool number = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: _ProfileText.label),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: number 
            ? const TextInputType.numberWithOptions(decimal: true) 
            : TextInputType.text,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => FocusScope.of(context).unfocus(),
          style: _ProfileText.input,
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }

  Widget _readOnlyTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _ProfilePalette.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _ProfilePalette.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(190),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 20, color: _ProfilePalette.text),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(), style: _ProfileText.label),
                const SizedBox(height: 4),
                Text(value, style: _ProfileText.bodyStrong),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameC.removeListener(_handlePreviewChange);
    _weightC.removeListener(_handlePreviewChange);
    _heightC.removeListener(_handlePreviewChange);
    _nameC.dispose();
    _weightC.dispose();
    _heightC.dispose();
    _calGoalC.dispose();
    _waterGoalC.dispose();
    super.dispose();
  }
}

class _ProfileGymBackdrop extends StatefulWidget {
  const _ProfileGymBackdrop();

  @override
  State<_ProfileGymBackdrop> createState() => _ProfileGymBackdropState();
}

class _ProfileGymBackdropState extends State<_ProfileGymBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return RepaintBoundary(
          child: Stack(
            fit: StackFit.expand,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _ProfilePalette.base,
                      Color(0xFFF7F8FB),
                      Color(0xFFF2F5F8),
                    ],
                  ),
                ),
              ),
              _blob(
                alignment: const Alignment(-1.0, -0.82),
                size: 260,
                color: _ProfilePalette.rgbRed,
                phase: 0,
                xTravel: 22,
                yTravel: 18,
              ),
              _blob(
                alignment: const Alignment(1.0, -0.3),
                size: 280,
                color: _ProfilePalette.rgbBlue,
                phase: math.pi / 2,
                xTravel: 28,
                yTravel: 22,
              ),
              _blob(
                alignment: const Alignment(-0.5, 0.92),
                size: 300,
                color: _ProfilePalette.rgbGreen,
                phase: math.pi,
                xTravel: 20,
                yTravel: 24,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _blob({
    required Alignment alignment,
    required double size,
    required Color color,
    required double phase,
    required double xTravel,
    required double yTravel,
  }) {
    final t = _controller.value * math.pi * 2 + phase;
    return Align(
      alignment: alignment,
      child: Transform.translate(
        offset: Offset(math.sin(t) * xTravel, math.cos(t * 0.82) * yTravel),
        child: IgnorePointer(
          child: Opacity(
            opacity: 0.88,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 58, sigmaY: 58),
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      color.withAlpha(122),
                      color.withAlpha(38),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.46, 1.0],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfilePalette {
  static const Color base = Color(0xFFF7F7F4);
  static const Color sheet = Color(0xFFF9FAFC);
  static const Color surface = Color(0xE9FFFFFF);
  static const Color surfaceStrong = Color(0xF3FFFFFF);
  static const Color field = Color(0xF7FFFFFF);
  static const Color border = Color(0x160E1620);
  static const Color text = Color(0xFF13171B);
  static const Color textSoft = Color(0xFF64707C);
  static const Color hint = Color(0xFF95A0AD);
  static const Color focus = Color(0xFF6E7D8C);
  static const Color shadow = Color(0x1A111827);
  static const Color highlightShadow = Color(0x15FF6B6B);
  static const Color goalSelected = Color(0xEEFFFFFF);
  static const Color destructive = Color(0xFFE38E8C);
  static const Color success = Color(0xFF1C7C54);
  static const Color successSoft = Color(0xFFE8F6EE);
  static const Color rgbRed = Color(0xFFFF6B6B);
  static const Color rgbBlue = Color(0xFF5AA9FF);
  static const Color rgbGreen = Color(0xFF7DFF8A);
}

class _ProfileText {
  static final TextStyle pageTitle = GoogleFonts.inter(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    color: _ProfilePalette.text,
    letterSpacing: -0.8,
  );

  static final TextStyle heroName = GoogleFonts.inter(
    fontSize: 30,
    fontWeight: FontWeight.w700,
    color: _ProfilePalette.text,
    letterSpacing: -0.9,
  );

  static final TextStyle sectionTitle = GoogleFonts.inter(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: _ProfilePalette.text,
    letterSpacing: -0.4,
  );

  static final TextStyle title = GoogleFonts.inter(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: _ProfilePalette.text,
  );

  static final TextStyle body = GoogleFonts.inter(
    fontSize: 14,
    color: _ProfilePalette.textSoft,
    height: 1.5,
  );

  static final TextStyle bodyStrong = GoogleFonts.inter(
    fontSize: 14,
    color: _ProfilePalette.text,
    fontWeight: FontWeight.w600,
    height: 1.45,
  );

  static final TextStyle caption = GoogleFonts.inter(
    fontSize: 11,
    color: _ProfilePalette.textSoft,
    fontWeight: FontWeight.w500,
  );

  static final TextStyle captionStrong = GoogleFonts.inter(
    fontSize: 11,
    color: _ProfilePalette.text,
    fontWeight: FontWeight.w600,
  );

  static final TextStyle label = GoogleFonts.inter(
    fontSize: 10,
    color: _ProfilePalette.hint,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
  );

  static final TextStyle input = GoogleFonts.inter(
    fontSize: 15,
    color: _ProfilePalette.text,
    fontWeight: FontWeight.w600,
  );

  static final TextStyle inputHint = GoogleFonts.inter(
    fontSize: 14,
    color: _ProfilePalette.hint,
    fontWeight: FontWeight.w500,
  );


  static final TextStyle goal = GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: _ProfilePalette.textSoft,
  );

  static final TextStyle goalActive = GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: _ProfilePalette.text,
  );

  static final TextStyle onDark = GoogleFonts.inter(
    fontSize: 13,
    color: Colors.white,
    fontWeight: FontWeight.w600,
  );

  static final TextStyle success = GoogleFonts.inter(
    fontSize: 11,
    color: _ProfilePalette.success,
    fontWeight: FontWeight.w700,
  );
}

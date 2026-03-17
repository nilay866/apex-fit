import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';
import '../services/exercise_animation_service.dart';
import '../widgets/exercise_form_guide.dart';

class ExerciseDetailScreen extends StatefulWidget {
  final Map<String, dynamic> exercise;
  const ExerciseDetailScreen({super.key, required this.exercise});

  @override
  State<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends State<ExerciseDetailScreen> {
  String? _animationUrl;
  String? _motionKey;
  bool _loadingAnimation = true;
  bool _imageError = false;

  @override
  void initState() {
    super.initState();
    _loadAnimation();
  }

  Future<void> _loadAnimation() async {
    final name = widget.exercise['name'] as String? ?? '';
    final builtInMotion =
        widget.exercise['animation_key'] as String? ??
        ExerciseAnimationService.getBuiltInMotionKey(name);
    // First use stored video_url if it's already a wger/exercisedb URL
    final stored = widget.exercise['video_url'] as String? ?? '';

    if (!ExerciseAnimationService.hasApiKey && builtInMotion != null) {
      if (mounted) {
        setState(() {
          _motionKey = builtInMotion;
          _animationUrl = null;
          _loadingAnimation = false;
        });
      }
      return;
    }

    // Try the ExerciseAnimationService (searches by exercise name — guaranteed match)
    final fetched = await ExerciseAnimationService.getGifUrl(name);

    if (mounted) {
      setState(() {
        _motionKey = builtInMotion;
        _animationUrl = fetched ?? (stored.isNotEmpty ? stored : null);
        _loadingAnimation = false;
      });
    }
  }

  Color _heatColor(int intensity) {
    if (intensity >= 5) return const Color(0xFFFF4B2B);
    if (intensity >= 4) return const Color(0xFFFF8C42);
    if (intensity >= 3) return const Color(0xFF4FC3F7);
    return ApexColors.t3;
  }

  String _heatLabel(int intensity) {
    if (intensity >= 5) return 'Primary';
    if (intensity >= 4) return 'Secondary';
    if (intensity >= 3) return 'Supporting';
    return 'Synergist';
  }

  Color get _difficultyColor {
    return switch (widget.exercise['difficulty'] as String? ?? '') {
      'Advanced' => ApexColors.red,
      'Intermediate' => ApexColors.orange,
      _ => ApexColors.accent,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ApexColors.bg,
      body: CustomScrollView(
        slivers: [
          // ─── Header with animation ─────────────────────────────────────
          SliverAppBar(
            backgroundColor: Colors.black,
            expandedHeight: 320,
            pinned: true,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: Colors.black,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Background gradient
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF0A0A0C), Color(0xFF141418)],
                        ),
                      ),
                    ),

                    // Exercise Animation (GIF or Image)
                    if (_loadingAnimation)
                      const Center(
                        child: CircularProgressIndicator(
                          color: ApexColors.accent,
                          strokeWidth: 2,
                        ),
                      )
                    else if (_motionKey != null &&
                        (!ExerciseAnimationService.hasApiKey || _imageError))
                      Center(
                        child: Hero(
                          tag: 'exercise_${widget.exercise['id']}',
                          child: ExerciseFormGuide(
                            motionKey: _motionKey!,
                            title:
                                '${widget.exercise['difficulty'] ?? 'Beginner'} motion loop for clean form',
                          ),
                        ),
                      )
                    else if (_animationUrl != null && !_imageError)
                      Center(
                        child: Hero(
                          tag: 'exercise_${widget.exercise['id']}',
                          child: Image.network(
                            _animationUrl!,
                            fit: BoxFit.contain,
                            height: 260,
                            gaplessPlayback: true, // Smooth GIF animation
                            loadingBuilder: (ctx, child, progress) {
                              if (progress == null) return child;
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CircularProgressIndicator(
                                      value: progress.expectedTotalBytes != null
                                          ? progress.cumulativeBytesLoaded /
                                                progress.expectedTotalBytes!
                                          : null,
                                      color: ApexColors.accent,
                                      strokeWidth: 2,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Loading animation…',
                                      style: TextStyle(
                                        color: ApexColors.t3,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) setState(() => _imageError = true);
                              });
                              if (_motionKey != null) {
                                return ExerciseFormGuide(
                                  motionKey: _motionKey!,
                                  title:
                                      '${widget.exercise['difficulty'] ?? 'Beginner'} motion loop for clean form',
                                );
                              }
                              return _NoAnimationPlaceholder(
                                name: widget.exercise['name'] ?? '',
                              );
                            },
                          ),
                        ),
                      )
                    else
                      _NoAnimationPlaceholder(
                        name: widget.exercise['name'] ?? '',
                      ),

                    // Bottom gradient overlay
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.transparent,
                            Colors.black.withAlpha(220),
                          ],
                          stops: const [0, 0.6, 1],
                        ),
                      ),
                    ),

                    // Exercise name + difficulty at bottom
                    Positioned(
                      bottom: 16,
                      left: 20,
                      right: 20,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Text(
                              widget.exercise['name'] ?? '',
                              style: GoogleFonts.inter(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                shadows: const [
                                  Shadow(blurRadius: 8, color: Colors.black),
                                ],
                              ),
                              maxLines: 2,
                            ),
                          ),
                          if ((widget.exercise['difficulty'] as String? ?? '')
                              .isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: _difficultyColor.withAlpha(220),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                widget.exercise['difficulty'] as String,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // "Exercise Form" badge at top right
                    if (_motionKey != null ||
                        ExerciseAnimationService.hasApiKey)
                      Positioned(
                        top: 60,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: ApexColors.accent.withAlpha(200),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.motion_photos_on_rounded,
                                color: Colors.black,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                ExerciseAnimationService.hasApiKey
                                    ? 'Animated'
                                    : 'Built-in Guide',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Metadata Tiles
                  Row(
                    children: [
                      Expanded(
                        child: _MetaTile(
                          icon: Icons.accessibility_new,
                          label: 'Muscle',
                          value: widget.exercise['primary_muscle'] ?? '',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MetaTile(
                          icon: Icons.fitness_center,
                          label: 'Equipment',
                          value: widget.exercise['equipment'] ?? '',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MetaTile(
                          icon: Icons.home_work_rounded,
                          label: 'Type',
                          value: widget.exercise['environment'] ?? '',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // ── Muscle Recruitment ─────────────────────────────────
                  if (widget.exercise['muscle_heatmap'] != null &&
                      (widget.exercise['muscle_heatmap'] as List)
                          .isNotEmpty) ...[
                    _SectionHeader(title: 'MUSCLE RECRUITMENT'),
                    const SizedBox(height: 14),
                    ...(widget.exercise['muscle_heatmap'] as List).map((m) {
                      final label = (m['muscle'] as String).toUpperCase();
                      final intensity = m['intensity'] as int? ?? 1;
                      final color = _heatColor(intensity);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 4,
                              height: 36,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    label,
                                    style: TextStyle(
                                      color: color,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    _heatLabel(intensity),
                                    style: TextStyle(
                                      color: ApexColors.t3,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // 5-dot intensity meter
                            Row(
                              children: List.generate(
                                5,
                                (i) => Container(
                                  margin: const EdgeInsets.only(left: 4),
                                  width: 9,
                                  height: 9,
                                  decoration: BoxDecoration(
                                    color: i < intensity
                                        ? color
                                        : color.withAlpha(25),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 28),
                  ],

                  // ── Instructions ───────────────────────────────────────
                  _SectionHeader(title: 'HOW TO PERFORM'),
                  const SizedBox(height: 14),
                  if (widget.exercise['instructions'] is List)
                    ...(widget.exercise['instructions'] as List)
                        .asMap()
                        .entries
                        .map(
                          (e) => Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    color: ApexColors.accent.withAlpha(20),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: ApexColors.accent.withAlpha(60),
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${e.key + 1}',
                                      style: TextStyle(
                                        color: ApexColors.accent,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    e.value.toString(),
                                    style: TextStyle(
                                      color: ApexColors.t2,
                                      fontSize: 15,
                                      height: 1.6,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                  else
                    Text(
                      widget.exercise['instructions']?.toString() ??
                          'Perform the movement under control with full range of motion.',
                      style: TextStyle(
                        color: ApexColors.t2,
                        fontSize: 15,
                        height: 1.6,
                      ),
                    ),
                  if (widget.exercise['form_cues'] is List &&
                      (widget.exercise['form_cues'] as List).isNotEmpty) ...[
                    const SizedBox(height: 28),
                    _SectionHeader(title: 'FORM CUES'),
                    const SizedBox(height: 14),
                    ...(widget.exercise['form_cues'] as List).map(
                      (cue) => _CueCard(
                        icon: Icons.check_circle_outline_rounded,
                        color: ApexColors.accent,
                        text: cue.toString(),
                      ),
                    ),
                  ],
                  if (widget.exercise['common_mistakes'] is List &&
                      (widget.exercise['common_mistakes'] as List)
                          .isNotEmpty) ...[
                    const SizedBox(height: 28),
                    _SectionHeader(title: 'AVOID THESE MISTAKES'),
                    const SizedBox(height: 14),
                    ...(widget.exercise['common_mistakes'] as List).map(
                      (mistake) => _CueCard(
                        icon: Icons.warning_amber_rounded,
                        color: ApexColors.orange,
                        text: mistake.toString(),
                      ),
                    ),
                  ],
                  if ((widget.exercise['beginner_tip'] as String? ?? '')
                      .isNotEmpty) ...[
                    const SizedBox(height: 28),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: ApexColors.blue.withAlpha(20),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: ApexColors.blue.withAlpha(60),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.school_rounded,
                            color: ApexColors.blue,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              widget.exercise['beginner_tip'].toString(),
                              style: const TextStyle(
                                color: ApexColors.t1,
                                fontSize: 13,
                                height: 1.6,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── No animation placeholder ──────────────────────────────────────────────

class _NoAnimationPlaceholder extends StatelessWidget {
  final String name;
  const _NoAnimationPlaceholder({required this.name});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.fitness_center_rounded,
            size: 64,
            color: ApexColors.accent.withAlpha(80),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Built-in guide unavailable for this move. Add a RapidAPI key for full animated demos.',
            style: TextStyle(color: ApexColors.t3, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

// ─── Helper widgets ────────────────────────────────────────────────────────

class _MetaTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _MetaTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ApexColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ApexColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: ApexColors.accent),
          const SizedBox(height: 10),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: ApexColors.t3,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: ApexColors.t1,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _CueCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _CueCard({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ApexColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ApexColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: ApexColors.t2,
                fontSize: 13,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: ApexColors.t1,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 36,
          height: 3,
          decoration: BoxDecoration(
            color: ApexColors.accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}

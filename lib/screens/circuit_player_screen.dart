import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import '../constants/colors.dart';
import '../constants/theme.dart';
import '../services/supabase_service.dart';

class CircuitPlayerScreen extends StatefulWidget {
  final Map<String, dynamic> workout;
  final VoidCallback onFinish;

  const CircuitPlayerScreen({
    super.key,
    required this.workout,
    required this.onFinish,
  });

  @override
  State<CircuitPlayerScreen> createState() => _CircuitPlayerScreenState();
}

class _CircuitPlayerScreenState extends State<CircuitPlayerScreen> {
  late List<Map<String, dynamic>> _exercises;
  int _curExIdx = 0;

  // States: 'prepare', 'work', 'rest', 'done'
  String _phase = 'prepare';
  int _timeRemaining = 10;
  Timer? _timer;

  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    _exercises = List<Map<String, dynamic>>.from(
      widget.workout['exercises'] ?? [],
    );
    if (_exercises.isNotEmpty) {
      _initVideoForCurrentExercise();
      _startPhase('prepare', 5); // 5 seconds preparation
    } else {
      _phase = 'done';
    }
  }

  void _initVideoForCurrentExercise() {
    _videoController?.dispose();
    _videoController = null;

    final ex = _exercises[_curExIdx];
    final url = ex['video_url'] as String?;

    if (url != null && url.isNotEmpty) {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(url))
        ..initialize().then((_) {
          _videoController!.setLooping(true);
          if (mounted && _phase == 'work') {
            _videoController!.play();
          }
          setState(() {});
        });
    }
  }

  void _startPhase(String phase, int duration) {
    setState(() {
      _phase = phase;
      _timeRemaining = duration;
      if (phase == 'work' && _videoController?.value.isInitialized == true) {
        _videoController!.play();
      } else {
        _videoController?.pause();
      }
    });

    _timer?.cancel();
    if (duration > 0) {
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (_timeRemaining > 1) {
          setState(() => _timeRemaining--);
        } else {
          t.cancel();
          _nextPhase();
        }
      });
    }
  }

  void _nextPhase() {
    if (_phase == 'prepare' || _phase == 'rest') {
      // Transition to work
      int workDuration =
          int.tryParse(
            _exercises[_curExIdx]['duration_sec']?.toString() ?? '45',
          ) ??
          45;
      _startPhase('work', workDuration);
    } else if (_phase == 'work') {
      // Finished work, move to rest or next exercise or done
      // In a real circuit, we might loop sets, but let's assume flat list for now.
      if (_curExIdx < _exercises.length - 1) {
        int restDuration =
            int.tryParse(
              _exercises[_curExIdx]['rest_sec']?.toString() ?? '15',
            ) ??
            15;
        _curExIdx++;
        _initVideoForCurrentExercise();
        _startPhase('rest', restDuration);
      } else {
        _startPhase('done', 0);
      }
    }
  }

  void _skipNext() {
    if (_curExIdx < _exercises.length - 1) {
      _curExIdx++;
      _initVideoForCurrentExercise();
      _startPhase('prepare', 3);
    } else {
      _startPhase('done', 0);
    }
  }

  void _skipPrev() {
    if (_curExIdx > 0) {
      _curExIdx--;
      _initVideoForCurrentExercise();
      _startPhase('prepare', 3);
    }
  }

  void _togglePlayPause() {
    if (_timer?.isActive == true) {
      _timer?.cancel();
      _videoController?.pause();
      setState(() {});
    } else {
      _startPhase(_phase, _timeRemaining);
    }
  }

  Future<void> _finishWorkout() async {
    try {
      await SupabaseService.createWorkoutLog({
        'user_id': SupabaseService.requireUserId(
          action: 'save your circuit workout',
        ),
        'workout_name': widget.workout['name'] ?? 'Circuit Training',
        'duration_min': ((_exercises.length * 60) / 60).round(), // Mock
        'total_volume': 0,
        'intensity': 'high',
        'completed_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
    if (mounted) widget.onFinish();
  }

  String _fmt(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _timer?.cancel();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_phase == 'done') {
      return Scaffold(
        backgroundColor: ApexColors.bg,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.check_circle,
                color: ApexColors.accent,
                size: 80,
              ),
              const SizedBox(height: 24),
              Text(
                'Circuit Complete!',
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: ApexColors.t1,
                ),
              ),
              const SizedBox(height: 32),
              GestureDetector(
                onTap: _finishWorkout,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: ApexColors.accent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Save & Exit',
                    style: TextStyle(
                      color: ApexColors.bg,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final ex = _exercises[_curExIdx];
    final isRest = _phase == 'rest' || _phase == 'prepare';
    final bgColor = isRest ? ApexColors.card : ApexColors.bg;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: widget.onFinish,
                    child: const Icon(
                      Icons.close,
                      color: ApexColors.t2,
                      size: 28,
                    ),
                  ),
                  Text(
                    isRest ? 'UP NEXT' : 'WORK',
                    style: TextStyle(
                      color: isRest ? ApexColors.blue : ApexColors.accent,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '${_curExIdx + 1} / ${_exercises.length}',
                    style: const TextStyle(
                      color: ApexColors.t2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Video or Image Area
            Expanded(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(24),
                ),
                clipBehavior: Clip.antiAlias,
                child:
                    _videoController != null &&
                        _videoController!.value.isInitialized
                    ? Stack(
                        alignment: Alignment.center,
                        children: [
                          VideoPlayer(_videoController!),
                          if (_timeRemaining <= 0 || _timer?.isActive == false)
                            Container(
                              color: Colors.black45,
                              child: const Center(
                                child: Icon(
                                  Icons.play_circle_fill,
                                  size: 60,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                        ],
                      )
                    : const Center(
                        child: Icon(
                          Icons.fitness_center,
                          size: 80,
                          color: ApexColors.border,
                        ),
                      ),
              ),
            ),

            // Exercise Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Text(
                ex['name']?.toUpperCase() ?? 'EXERCISE',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: ApexColors.t1,
                ),
              ),
            ),

            // Massive Exertion Timer
            Text(
              _fmt(_timeRemaining),
              style: ApexTheme.mono(
                size: 96,
                color: isRest ? ApexColors.blue : ApexColors.accent,
              ).copyWith(fontWeight: FontWeight.w300),
            ),

            // Media Controls
            Padding(
              padding: const EdgeInsets.only(bottom: 40, top: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    iconSize: 40,
                    color: ApexColors.t2,
                    icon: const Icon(Icons.skip_previous),
                    onPressed: _skipPrev,
                  ),
                  GestureDetector(
                    onTap: _togglePlayPause,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: ApexColors.surface,
                        border: Border.all(color: ApexColors.border, width: 2),
                      ),
                      child: Icon(
                        _timer?.isActive == true
                            ? Icons.pause
                            : Icons.play_arrow,
                        size: 40,
                        color: ApexColors.t1,
                      ),
                    ),
                  ),
                  IconButton(
                    iconSize: 40,
                    color: ApexColors.t2,
                    icon: const Icon(Icons.skip_next),
                    onPressed: _skipNext,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

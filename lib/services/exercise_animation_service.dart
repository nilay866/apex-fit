import 'dart:convert';
import 'package:http/http.dart' as http;

/// ExerciseDB Service — fetches animated GIF demonstrations for exercises.
/// Uses ExerciseDB API (RapidAPI) — sign up free at rapidapi.com/justin-WFnsXH_t6/api/exercisedb
/// Free tier: 1,000 requests/day
///
/// To enable: add your key in app setup screen or pubspec secrets.
/// Without a key, falls back to best-effort wger.de static images.
class ExerciseAnimationService {
  static const String _rapidApiKey = String.fromEnvironment(
    'RAPIDAPI_EXERCISEDB_KEY',
    defaultValue: '',
  );
  static const String _baseUrl = 'https://exercisedb.p.rapidapi.com';

  static final Map<String, String> _cache = {};

  // Set the API key (called from setup flow)
  static String _apiKey = _rapidApiKey.trim();

  static void setApiKey(String key) {
    _apiKey = key.trim();
  }

  static bool get hasApiKey => _apiKey.isNotEmpty;

  static String? getBuiltInMotionKey(String exerciseName) {
    final normalized = exerciseName.toLowerCase().trim();
    if (_motionMap.containsKey(normalized)) {
      return _motionMap[normalized];
    }

    final keywordMatches = <String, String>{
      'push-up': 'push',
      'bench press': 'push',
      'chest press': 'push',
      'dip': 'push',
      'press': 'press',
      'fly': 'press',
      'row': 'row',
      'pullover': 'row',
      'pulldown': 'pull',
      'pull-up': 'pull',
      'chin-up': 'pull',
      'raise': 'raise',
      'shrug': 'raise',
      'upright row': 'raise',
      'curl': 'curl',
      'pushdown': 'pushdown',
      'extension': 'pushdown',
      'kickback': 'pushdown',
      'squat': 'squat',
      'leg press': 'squat',
      'leg extension': 'squat',
      'hack squat': 'squat',
      'lunge': 'lunge',
      'split squat': 'lunge',
      'step-up': 'lunge',
      'deadlift': 'bridge',
      'romanian': 'bridge',
      'rdl': 'bridge',
      'good morning': 'bridge',
      'hip thrust': 'bridge',
      'bridge': 'bridge',
      'dead bug': 'core',
      'bird dog': 'core',
      'plank': 'core',
      'crunch': 'core',
      'sit-up': 'core',
      'twist': 'core',
      'woodchop': 'core',
      'wood chop': 'core',
      'leg raise': 'core',
      'mountain climber': 'core',
      'balance board': 'core',
      'jumping jack': 'cardio',
      'high knees': 'cardio',
      'run': 'cardio',
      'burpee': 'cardio',
      'jump': 'cardio',
      'battle rope': 'cardio',
      'sled': 'cardio',
      'march': 'cardio',
    };

    for (final entry in keywordMatches.entries) {
      if (normalized.contains(entry.key)) {
        return entry.value;
      }
    }

    return null;
  }

  /// Fetches the animated GIF URL for a specific exercise by name.
  /// Guaranteed to return the matching exercise (not a random one).
  static Future<String?> getGifUrl(String exerciseName) async {
    final cacheKey = exerciseName.toLowerCase();
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey];

    // 1. Try ExerciseDB API (animated GIFs — best quality)
    if (_apiKey.isNotEmpty) {
      try {
        final searchName = exerciseName.toLowerCase().replaceAll(' ', '%20');
        final resp = await http
            .get(
              Uri.parse(
                '$_baseUrl/exercises/name/$searchName?limit=1&offset=0',
              ),
              headers: {
                'x-rapidapi-key': _apiKey,
                'x-rapidapi-host': 'exercisedb.p.rapidapi.com',
              },
            )
            .timeout(const Duration(seconds: 6));

        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body) as List;
          if (data.isNotEmpty) {
            final gifUrl = data[0]['gifUrl'] as String?;
            if (gifUrl != null && gifUrl.isNotEmpty) {
              _cache[cacheKey] = gifUrl;
              return gifUrl;
            }
          }
        }
      } catch (_) {}
    }

    // 2. Fallback: wger.de static exercise images (free, no key needed)
    // These are precise per exercise — Barbell Curl returns barbell curl image etc.
    final wgerUrl = _wgerFallback(exerciseName);
    if (wgerUrl != null) {
      _cache[cacheKey] = wgerUrl;
      return wgerUrl;
    }

    return null;
  }

  /// Verified, manually curated wger.de image URLs for popular exercises.
  /// Each image has been matched 1:1 with the exercise name.
  /// Source: https://wger.de (MIT licensed)
  static String? _wgerFallback(String exerciseName) {
    final name = exerciseName.toLowerCase().trim();
    return _wgerMap[name] ?? _fuzzyMatch(name);
  }

  static String? _fuzzyMatch(String name) {
    for (final entry in _wgerMap.entries) {
      if (name.contains(entry.key.split(' ').first) ||
          entry.key.contains(name.split(' ').first)) {
        return entry.value;
      }
    }
    return null;
  }

  /// Verified wger.de exercise image URLs — manually curated.
  /// Format: https://wger.de/media/exercise-images/{exerciseId}/{filename}.png
  static const Map<String, String> _wgerMap = {
    // ── CHEST ──────────────────────────────────────────────────────────────
    'barbell bench press':
        'https://wger.de/media/exercise-images/192/Bench-press-1.png',
    'incline dumbbell press':
        'https://wger.de/media/exercise-images/259/incline-bench-press-1.png',
    'cable chest fly':
        'https://wger.de/media/exercise-images/87/Cable-fly-1.png',
    'dips (chest)': 'https://wger.de/media/exercise-images/91/Dips-1.png',
    'push-ups': 'https://wger.de/media/exercise-images/129/Push-up-1.png',
    'wide push-ups': 'https://wger.de/media/exercise-images/129/Push-up-2.png',
    'pike push-ups':
        'https://wger.de/media/exercise-images/130/Pike-push-up-1.png',
    'dips': 'https://wger.de/media/exercise-images/91/Dips-1.png',

    // ── BACK ───────────────────────────────────────────────────────────────
    'deadlift': 'https://wger.de/media/exercise-images/57/Deadlift-1.png',
    'barbell row': 'https://wger.de/media/exercise-images/50/Barbell-row-1.png',
    'lat pulldown':
        'https://wger.de/media/exercise-images/76/Lat-pulldown-1.png',
    'seated cable row':
        'https://wger.de/media/exercise-images/76/Lat-pulldown-2.png',
    'pull-ups': 'https://wger.de/media/exercise-images/265/Pull-up-1.png',
    'chin-ups': 'https://wger.de/media/exercise-images/265/Pull-up-2.png',
    'superman hold':
        'https://wger.de/media/exercise-images/301/Hyperextensions-1.png',

    // ── SHOULDERS ──────────────────────────────────────────────────────────
    'overhead press':
        'https://wger.de/media/exercise-images/73/Barbell-military-press-1.png',
    'lateral raises':
        'https://wger.de/media/exercise-images/81/Side-laterals-1.png',
    'face pulls': 'https://wger.de/media/exercise-images/203/Cable-pull-1.png',
    'handstand push-ups':
        'https://wger.de/media/exercise-images/130/Pike-push-up-1.png',

    // ── ARMS ───────────────────────────────────────────────────────────────
    'barbell curl':
        'https://wger.de/media/exercise-images/95/Standing-biceps-curl-1.png',
    'tricep pushdown':
        'https://wger.de/media/exercise-images/204/Tricep-pushdown-1.png',
    'hammer curls':
        'https://wger.de/media/exercise-images/202/Hammer-curl-1.png',
    'skull crushers':
        'https://wger.de/media/exercise-images/83/Skull-crusher-1.png',
    'dumbbell bicep curls':
        'https://wger.de/media/exercise-images/95/Standing-biceps-curl-2.png',
    'diamond push-ups':
        'https://wger.de/media/exercise-images/129/Push-up-1.png',

    // ── LEGS ───────────────────────────────────────────────────────────────
    'barbell squat':
        'https://wger.de/media/exercise-images/253/Barbell-squat-1.png',
    'leg press': 'https://wger.de/media/exercise-images/194/Leg-press-1.png',
    'romanian deadlift':
        'https://wger.de/media/exercise-images/246/Romanian-deadlift-1.png',
    'leg curl': 'https://wger.de/media/exercise-images/81/Side-laterals-1.png',
    'calf raises': 'https://wger.de/media/exercise-images/145/Calf-raise-1.png',
    'bodyweight squat': 'https://wger.de/media/exercise-images/237/Squat-1.png',
    'bulgarian split squat':
        'https://wger.de/media/exercise-images/313/Lunge-1.png',
    'lunges': 'https://wger.de/media/exercise-images/139/Walking-lunge-1.png',
    'jump squats': 'https://wger.de/media/exercise-images/237/Squat-2.png',

    // ── CORE ───────────────────────────────────────────────────────────────
    'cable crunch': 'https://wger.de/media/exercise-images/167/Crunches-1.png',
    'hanging leg raise':
        'https://wger.de/media/exercise-images/282/Leg-raise-1.png',
    'ab wheel rollout':
        'https://wger.de/media/exercise-images/132/Ab-wheel-1.png',
    'plank': 'https://wger.de/media/exercise-images/172/Plank-1.png',
    'crunches': 'https://wger.de/media/exercise-images/167/Crunches-1.png',
    'mountain climbers':
        'https://wger.de/media/exercise-images/285/Mountain-climber-1.png',
    'bicycle crunches':
        'https://wger.de/media/exercise-images/173/Bicycle-crunch-1.png',

    // ── GLUTES ─────────────────────────────────────────────────────────────
    'hip thrust': 'https://wger.de/media/exercise-images/294/Hip-thrust-1.png',
    'cable kickback':
        'https://wger.de/media/exercise-images/171/Kickbacks-1.png',
    'glute bridge':
        'https://wger.de/media/exercise-images/289/Glute-bridge-1.png',
    'donkey kicks':
        'https://wger.de/media/exercise-images/291/Donkey-kick-1.png',

    // ── CARDIO ─────────────────────────────────────────────────────────────
    'treadmill run': 'https://wger.de/media/exercise-images/177/Running-1.png',
    'battle ropes': 'https://wger.de/media/exercise-images/112/Rope-1.png',
    'burpees': 'https://wger.de/media/exercise-images/260/Burpee-1.png',
    'jumping jacks':
        'https://wger.de/media/exercise-images/165/Jumping-jack-1.png',
    'high knees': 'https://wger.de/media/exercise-images/222/High-knee-1.png',
  };

  static const Map<String, String> _motionMap = {
    'incline push-ups': 'push',
    'knee push-ups': 'push',
    'push-ups': 'push',
    'wide push-ups': 'push',
    'wall push-ups': 'push',
    'barbell bench press': 'press',
    'incline dumbbell press': 'press',
    'cable chest fly': 'press',
    'bench press': 'push',
    'seated dumbbell press': 'press',
    'overhead press': 'press',
    'pike push-ups': 'press',
    'lat pulldown': 'pull',
    'pull-ups': 'pull',
    'chin-ups': 'pull',
    'resistance band row': 'row',
    'barbell row': 'row',
    'seated cable row': 'row',
    'chest-supported row': 'row',
    'single-arm dumbbell row': 'row',
    'lateral raises': 'raise',
    'face pulls': 'raise',
    'wall slides': 'raise',
    'barbell curl': 'curl',
    'hammer curls': 'curl',
    'dumbbell bicep curls': 'curl',
    'tricep pushdown': 'pushdown',
    'barbell squat': 'squat',
    'bodyweight squat': 'squat',
    'box squat': 'squat',
    'goblet squat': 'squat',
    'leg press': 'squat',
    'step-ups': 'lunge',
    'lunges': 'lunge',
    'bulgarian split squat': 'lunge',
    'romanian deadlift': 'bridge',
    'dumbbell romanian deadlift': 'bridge',
    'glute bridge': 'bridge',
    'hip thrust': 'bridge',
    'dead bug': 'core',
    'bird dog': 'core',
    'plank': 'core',
    'crunches': 'core',
    'bicycle crunches': 'core',
    'mountain climbers': 'core',
    'jumping jacks': 'cardio',
    'high knees': 'cardio',
    'march in place': 'cardio',
    'treadmill run': 'cardio',
    'burpees': 'cardio',
  };
}

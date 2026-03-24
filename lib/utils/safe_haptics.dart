import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:haptic_feedback/haptic_feedback.dart';

/// Web-safe haptics wrapper. No-op on web where haptics are unavailable.
class SafeHaptics {
  SafeHaptics._();

  static Future<void> vibrate(HapticsType type) async {
    if (kIsWeb) return;
    try {
      await Haptics.vibrate(type);
    } catch (_) {
      // Silently ignore on unsupported platforms
    }
  }
}

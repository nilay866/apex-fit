import 'package:flutter/material.dart';

class ApexColors {
  // ── Backgrounds ──────────────────────────────────────────────
  static const Color bg = Color(0xFFF4F5F7);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceStrong = Color(0xFFF9F9FB);
  static const Color card = Color(0xFFFFFFFF);
  static const Color cardAlt = Color(0xFFF2F3F5);

  // ── Borders & Shadows ────────────────────────────────────────
  static const Color border = Color(0x0F000000);
  static const Color borderStrong = Color(0x18000000);
  static const Color shadow = Color(0x0A000000);

  // ── Primary Accent (Apple Pink/Red) ──────────────────────────
  static const Color accent = Color(0xFFFF2D55);
  static const Color accentDim = Color(0x12FF2D55);
  static const Color accentSoft = Color(0xFFFF6B81);

  // ── Semantic Colors ──────────────────────────────────────────
  static const Color blue = Color(0xFF007AFF);
  static const Color orange = Color(0xFFFF9500);
  static const Color purple = Color(0xFFAF52DE);
  static const Color red = Color(0xFFFF3B30);
  static const Color yellow = Color(0xFFFFCC00);
  static const Color cyan = Color(0xFF5AC8FA);
  static const Color pink = Color(0xFFFF2D55);
  static const Color green = Color(0xFF34C759);

  // ── Activity Ring Colors ─────────────────────────────────────
  static const Color ringMove = Color(0xFFFF2D55);
  static const Color ringExercise = Color(0xFF30D158);
  static const Color ringStand = Color(0xFF5AC8FA);

  // ── Text Colors ──────────────────────────────────────────────
  static const Color ink = Color(0xFFFFFFFF);
  static const Color t1 = Color(0xFF1C1C1E);
  static const Color t2 = Color(0xFF636366);
  static const Color t3 = Color(0xFF8E8E93);

  // ── Chart / Glow Colors ──────────────────────────────────────
  static const Color glowRed = Color(0xFFFF2D55);
  static const Color glowBlue = Color(0xFF007AFF);
  static const Color glowGreen = Color(0xFF34C759);

  // ── Dark action color (for black buttons) ────────────────────
  static const Color darkAction = Color(0xFF1C1C1E);

  // ── Overlay / Modal Colors ───────────────────────────────────
  /// Semi-transparent dark overlay for modals / banners (94% opaque)
  static const Color overlay = Color(0xF2000000);
  /// Light scrim for bottom sheets
  static const Color scrim = Color(0x80000000);

  // ── Pace / Map UI Colors ─────────────────────────────────────
  /// Light blue used for pace display on map screen
  static const Color paceBlue = Color(0xFF64B5F6);

  // ── NFI Ring Colors ──────────────────────────────────────────
  /// Amber used for mid-range NFI score
  static const Color nfiAmber = Color(0xFFFFAA00);
  /// Red used for low NFI score
  static const Color nfiRed = Color(0xFFFF3C50);
}

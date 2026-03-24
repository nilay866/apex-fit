import 'dart:convert';

import 'package:flutter/services.dart';

class LocalExerciseCatalogService {
  static List<Map<String, dynamic>>? _cache;

  static Future<List<Map<String, dynamic>>> getExercises({
    String? muscle,
    String? equipment,
    String? environment,
    String? taxonomy,
  }) async {
    final catalog = await _loadCatalog();
    return catalog
        .where((exercise) {
          if (muscle != null && exercise['primary_muscle'] != muscle) {
            return false;
          }
          if (equipment != null && exercise['equipment'] != equipment) {
            return false;
          }
          if (environment != null &&
              exercise['environment'] != environment &&
              exercise['environment'] != 'Both') {
            return false;
          }
          if (taxonomy != null) {
            final folder = (exercise['taxonomy_folder'] ?? '').toString();
            if (!folder.toLowerCase().contains(taxonomy.toLowerCase())) {
              return false;
            }
          }
          return true;
        })
        .toList(growable: false);
  }

  static Future<List<Map<String, dynamic>>> _loadCatalog() async {
    if (_cache != null) {
      return _cache!;
    }

    try {
      final raw = await rootBundle.loadString(
        'assets/data/exercise_catalog.json',
      );
      final decoded = jsonDecode(raw) as List<dynamic>;
      _cache = decoded
          .whereType<Map<String, dynamic>>()
          .map((exercise) => Map<String, dynamic>.from(exercise))
          .toList(growable: false);
      return _cache!;
    } catch (_) {
      _cache = const [];
      return _cache!;
    }
  }
}

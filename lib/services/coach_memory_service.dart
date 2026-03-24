import 'dart:convert';
import 'package:apex_ai/services/ai_service.dart';

/// Manages the AI coach's persistent memory for a user.
class CoachMemoryService {
  /// Extracts key facts from a conversation using the AI.
  /// Returns a Map with string keys like "injury", "goal", "preference".
  static Future<Map<String, dynamic>> extractKeyFacts(
    List<Map<String, String>> messages,
  ) async {
    try {
      final transcript =
          messages.map((m) => '${m['role']}: ${m['content']}').join('\n');

      final prompt = '''
You are a fitness coach assistant. Read this conversation and extract any important facts about the user.
Return ONLY a valid JSON object. No markdown, no explanation.
Keys to extract (only include if mentioned): 
  "injuries" (array of strings), 
  "goals" (array of strings), 
  "preferences" (array of strings),
  "schedule" (string),
  "equipment" (array of strings),
  "diet_notes" (string)

Conversation:
$transcript

JSON:''';

      final response = await AIService.generate(prompt);
      final cleaned =
          response.replaceAll('```json', '').replaceAll('```', '').trim();

      // Safe parse
      try {
        final a = cleaned.indexOf('{');
        final b = cleaned.lastIndexOf('}');
        if (a != -1 && b != -1 && b > a) {
          final jsonStr = cleaned.substring(a, b + 1);
          final decoded = Map<String, dynamic>.from(
            jsonDecode(jsonStr) as Map,
          );
          return decoded;
        }
        return {};
      } catch (_) {
        return {};
      }
    } catch (_) {
      return {};
    }
  }

  /// Builds a memory context string to inject into AI prompts.
  static String buildMemoryContext(Map<String, dynamic> memory) {
    if (memory.isEmpty) return '';

    final buffer =
        StringBuffer('IMPORTANT USER CONTEXT (from previous conversations):\n');

    if (memory['injuries'] != null && memory['injuries'] is List) {
      buffer.writeln(
        '- Injuries/limitations: ${(memory['injuries'] as List).join(', ')}',
      );
    }
    if (memory['goals'] != null && memory['goals'] is List) {
      buffer.writeln('- Goals: ${(memory['goals'] as List).join(', ')}');
    }
    if (memory['preferences'] != null && memory['preferences'] is List) {
      buffer.writeln(
        '- Preferences: ${(memory['preferences'] as List).join(', ')}',
      );
    }
    if (memory['schedule'] != null) {
      buffer.writeln('- Schedule: ${memory['schedule']}');
    }
    if (memory['equipment'] != null && memory['equipment'] is List) {
      buffer.writeln(
        '- Equipment: ${(memory['equipment'] as List).join(', ')}',
      );
    }
    if (memory['diet_notes'] != null) {
      buffer.writeln('- Diet notes: ${memory['diet_notes']}');
    }
    return buffer.toString();
  }

  /// Merges new facts into existing memory (non-destructive).
  static Map<String, dynamic> mergeMemory(
    Map<String, dynamic> existing,
    Map<String, dynamic> newFacts,
  ) {
    final merged = Map<String, dynamic>.from(existing);
    newFacts.forEach((key, value) {
      if (value is List && existing[key] is List) {
        // Merge arrays, deduplicate
        final combined = <dynamic>{...(existing[key] as List), ...value}
            .toList();
        merged[key] = combined;
      } else if (value != null) {
        merged[key] = value;
      }
    });
    return merged;
  }
}

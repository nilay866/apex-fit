import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import '../supabase_service.dart';
import 'ai_provider.dart';

class BedrockProvider implements AIProvider {
  final String? modelId;

  BedrockProvider({this.modelId});

  @override
  Future<String> generate(String prompt) async {
    final session = SupabaseService.client.auth.currentSession;
    if (session == null) throw Exception('User not authenticated');

    final response = await http.post(
      Uri.parse(SupabaseService.client.rest.url.replaceAll('/rest/v1', '/functions/v1/bedrock-proxy')),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${session.accessToken}',
      },
      body: jsonEncode({
        'prompt': prompt,
        if (modelId != null) 'modelId': modelId,
      }),
    );

    if (response.statusCode != 200) {
      // SEC-FIX: Don't expose raw server response to user — log it instead
      debugPrint('Bedrock proxy error ${response.statusCode}: ${response.body}');
      throw Exception('AI request failed. Please try again.');
    }

    final data = jsonDecode(response.body);
    return data['result'] ?? '';
  }

  @override
  Future<bool> testConnection() async {
    try {
      await generate('ping');
      return true;
    } catch (_) {
      return false;
    }
  }
}

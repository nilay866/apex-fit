import 'package:google_generative_ai/google_generative_ai.dart';
import 'ai_provider.dart';

class GeminiProvider implements AIProvider {
  final String apiKey;
  late final GenerativeModel _model;

  GeminiProvider(this.apiKey) {
    _model = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: apiKey,
    );
  }

  @override
  Future<String> generate(String prompt) async {
    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      return response.text ?? '';
    } catch (e) {
      if (e.toString().contains('429')) {
        throw Exception('Rate limit — wait a moment and retry');
      }
      throw Exception('Gemini Error: $e');
    }
  }

  @override
  Future<bool> testConnection() async {
    try {
      final response = await _model.generateContent([Content.text('ping')]);
      return response.text != null;
    } catch (_) {
      return false;
    }
  }
}

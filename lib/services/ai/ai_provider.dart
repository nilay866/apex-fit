abstract class AIProvider {
  Future<String> generate(String prompt);
  Future<bool> testConnection();
}

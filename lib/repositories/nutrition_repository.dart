import '../services/supabase_service.dart';
import '../services/nutrition_service.dart';
import 'auth_repository.dart';

/// Repository wrapping SupabaseService nutrition methods + daily summaries
class NutritionRepository {
  const NutritionRepository();

  Future<List<Map<String, dynamic>>> getTodayLogs() async {
    final userId = authRepository.requireUserId();
    return SupabaseService.getNutritionLogs(userId, limit: 100);
  }

  Future<void> logFood(Map<String, dynamic> food) async {
    await SupabaseService.createNutritionLog({
      'user_id': authRepository.requireUserId(),
      ...food,
    });
  }

  Future<Map<String, double>> getDailyTotals() async {
    final logs = await getTodayLogs();
    return NutritionService.dailyTotals(logs);
  }

  Future<Map<String, double>> getMacroPercentages() async {
    final totals = await getDailyTotals();
    return NutritionService.macroPercentages(totals);
  }

  /// Water intake
  Future<void> logWater(int amountMl) async {
    try {
      await SupabaseService.logWater(
        authRepository.requireUserId(),
        amountMl,
      );
    } catch (_) {}
  }

  Future<int> getTodayWater() async {
    try {
      return await SupabaseService.getTodayWater(
        authRepository.requireUserId(),
      );
    } catch (_) {
      return 0;
    }
  }
}

const nutritionRepository = NutritionRepository();

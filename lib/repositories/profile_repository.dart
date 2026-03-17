import '../services/supabase_service.dart';
import 'auth_repository.dart';

class ProfileRepository {
  const ProfileRepository();

  Future<Map<String, dynamic>?> getCurrentProfile() async {
    final userId = authRepository.currentUserId;
    if (userId == null) return null;
    return SupabaseService.getProfile(userId);
  }

  Future<void> updateCurrentProfile(Map<String, dynamic> data) async {
    await SupabaseService.updateProfile(authRepository.requireUserId(), data);
  }
}

const profileRepository = ProfileRepository();

import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

class AuthRequiredException implements Exception {
  final String message;

  const AuthRequiredException(this.message);

  @override
  String toString() => message;
}

class AuthRepository {
  const AuthRepository();

  User? get currentUser => SupabaseService.currentUser;

  String? get currentUserId => currentUser?.id;

  String requireUserId() {
    final userId = currentUserId;
    if (userId == null) {
      throw const AuthRequiredException(
        'No authenticated user is available for this action.',
      );
    }
    return userId;
  }

  Stream<User?> sessionChanges() {
    return SupabaseService.client.auth.onAuthStateChange.map(
      (authState) => authState.session?.user,
    );
  }

  Future<AuthResponse> signIn(String email, String password) {
    return SupabaseService.signIn(email, password);
  }

  Future<AuthResponse> signUp(String email, String password, String name) {
    return SupabaseService.signUp(email, password, name);
  }

  Future<void> signOut() {
    return SupabaseService.signOut();
  }
}

const authRepository = AuthRepository();

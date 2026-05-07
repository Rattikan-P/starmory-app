import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  bool get isLoggedIn => _client.auth.currentSession != null;
  String? get currentUserId => _client.auth.currentSession?.user.id;

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? displayName,
    String? languageLevel,
    String? englishVariant,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'display_name': displayName,
        'language_level': languageLevel,
        'english_variant': englishVariant,
      }..removeWhere((key, value) => value == null),
    );

    // Also update the users table with language level and variant
    if (response.user != null) {
      await _client.from('users').upsert({
        'id': response.user!.id,
        'email': email,
        'display_name': displayName,
        'language_level': languageLevel,
        'english_variant': englishVariant,
      }..removeWhere((key, value) => value == null));

      // Auto login after registration
      await signIn(email: email, password: password);
    }

    return response;
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  Future<void> updatePassword(String newPassword) async {
    await _client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  Future<void> deleteAccount() async {
    final userId = currentUserId;
    if (userId == null) throw Exception('No user logged in');

    await _client.from('users').delete().eq('id', userId);
    await _client.auth.admin.deleteUser(userId);
  }
}

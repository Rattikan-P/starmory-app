import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  // Session auto-persisted by Supabase SDK (no manual storage needed)
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

    // Call Edge Function to delete account completely (PDPA compliant)
    final response = await _client.functions.invoke(
      'delete-account',
      body: {'userId': userId},
    );

    if (response.status != 200) {
      throw Exception(response.data['error'] ?? 'Failed to delete account');
    }

    // Sign out from current session
    await signOut();
  }

  // Send OTP to email (for both login and signup)
  Future<void> sendOtp(String email) async {
    await _client.auth.signInWithOtp(
      email: email,
      emailRedirectTo: null, // null = use OTP code instead of magic link
    );
  }

  // Verify OTP and complete auth
  // Returns a tuple: (AuthResponse, isNewUser)
  Future<Map<String, dynamic>> verifyOtp({
    required String email,
    required String token,
    String? displayName,
    String? languageLevel,
    String? englishVariant,
  }) async {
    final response = await _client.auth.verifyOTP(
      email: email,
      token: token,
      type: OtpType.email,
    );

    // Check if this is a new user (created within last minute via OTP)
    final createdAt = response.user?.createdAt;
    final isNewUser = createdAt != null &&
        DateTime.now().difference(DateTime.parse(createdAt)) < const Duration(minutes: 1);

    return {
      'response': response,
      'isNewUser': isNewUser,
    };
  }

  // Update user preferences (called after user chooses)
  Future<void> updateUserPreferences({
    required String userId,
    required String email,
    String? displayName,
    String? languageLevel,
    String? englishVariant,
  }) async {
    final data = {
      'id': userId,
      'email': email,
      'display_name': displayName,
      'language_level': languageLevel,
      'english_variant': englishVariant,
    }..removeWhere((key, value) => value == null);

    await _client.from('users').upsert(data);

    // Also update user metadata in auth
    await _client.auth.updateUser(
      UserAttributes(data: {
        'display_name': displayName,
        'language_level': languageLevel,
        'english_variant': englishVariant,
      }..removeWhere((key, value) => value == null)),
    );
  }

  // Fetch user data from users table (source of truth)
  Future<Map<String, dynamic>?> fetchUserData(String userId) async {
    final response = await _client
        .from('users')
        .select()
        .eq('id', userId)
        .maybeSingle();

    return response;
  }
}

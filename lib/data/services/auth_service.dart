import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:starmory_app/data/services/google_auth_service.dart';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;
  final GoogleAuthService _googleAuthService = GoogleAuthService();

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

    if (response.user != null) {
      await _client
          .from('users')
          .upsert(
            {
              'id': response.user!.id,
              'email': email,
              'display_name': displayName,
              'language_level': languageLevel,
              'english_variant': englishVariant,
            }..removeWhere((key, value) => value == null),
          );

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
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  Future<void> deleteAccount() async {
    final userId = currentUserId;
    if (userId == null) throw Exception('No user logged in');

    final response = await _client.functions.invoke(
      'delete-account',
      body: {'userId': userId},
    );

    if (response.status != 200) {
      throw Exception(response.data['error'] ?? 'Failed to delete account');
    }

    await signOut();
  }

  // Send OTP to email (for both login and signup)
  Future<void> sendOtp(String email) async {
    await _client.auth.signInWithOtp(email: email, emailRedirectTo: null);
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

    // เช็ค isNewUser จาก users table โดยตรง
    final userId = response.user?.id;
    bool isNewUser = false;
    if (userId != null) {
      final userData = await _client
          .from('users')
          .select('id, language_level, onboarding_completed')
          .eq('id', userId)
          .maybeSingle();

      isNewUser = userData == null || userData['onboarding_completed'] != true;
    }

    return {'response': response, 'isNewUser': isNewUser};
  }

  // Update user preferences (called after user chooses)
  Future<void> updateUserPreferences({
    required String userId,
    required String email,
    String? displayName,
    String? languageLevel,
    String? englishVariant,
    int? termsVersion,
  }) async {
    final data = {
      'id': userId,
      'email': email,
      'display_name': displayName,
      'language_level': languageLevel,
      'english_variant': englishVariant,
      if (termsVersion != null) 'terms_version': termsVersion,
    }..removeWhere((key, value) => value == null);

    await _client.from('users').upsert(data);

    await _client.auth.updateUser(
      UserAttributes(
        data: {
          'display_name': displayName,
          'language_level': languageLevel,
          'english_variant': englishVariant,
          if (termsVersion != null) 'terms_version': termsVersion,
        }..removeWhere((key, value) => value == null),
      ),
    );
  }

  // Get user's accepted terms version from Supabase
  Future<int?> getUserTermsVersion(String userId) async {
    final response = await _client
        .from('users')
        .select('terms_version')
        .eq('id', userId)
        .maybeSingle();

    return response?['terms_version'] as int?;
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

  // Google Authentication methods
  Future<bool> signInWithGoogle({bool forceAccountSelection = false}) async {
  return await _googleAuthService.signInWithGoogle(
    forceAccountSelection: forceAccountSelection,
  );
}

  Future<void> signOutFromGoogle() async {
    await _googleAuthService.signOutFromGoogle();
  }

  bool get isGoogleLoggedIn => _googleAuthService.isLoggedIn;
}

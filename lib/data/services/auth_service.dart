import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:starmory_app/data/services/google_auth_service.dart';

class AuthService {
  final SupabaseClient _client;
  final GoogleAuthService _googleAuthService;

  /// Create AuthService with optional SupabaseClient for testing
  /// If no client provided, uses the default Supabase instance
  AuthService({SupabaseClient? client, GoogleAuthService? googleAuthService})
      : _client = client ?? Supabase.instance.client,
        _googleAuthService = googleAuthService ?? GoogleAuthService();

  bool get isLoggedIn => _client.auth.currentSession != null;
  String? get currentUserId => _client.auth.currentSession?.user.id;

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<void> deleteAccount() async {
    final userId = currentUserId;
    if (userId == null) throw Exception('No user logged in');

    try {
      print('🗑️ [AuthService] Deleting account for user: $userId');

      // Add timeout to prevent hanging if Edge Function is stuck
      final response = await _client.functions.invoke(
        'delete-account',
        body: {'userId': userId},
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('⏱️ [AuthService] delete-account function timeout after 10s');
          throw Exception('Delete account request timeout. Please try again.');
        },
      );

      if (response.status != 200) {
        final error = response.data['error'] ?? 'Failed to delete account';
        print('❌ [AuthService] delete-account failed: $error (status: ${response.status})');
        throw Exception(error);
      }

      print('✅ [AuthService] Account deleted successfully for user: $userId');
    } catch (e) {
      print('❌ [AuthService] deleteAccount error: $e');
      // Re-throw to let caller handle the error
      rethrow;
    } finally {
      // ⭐ CRITICAL: Always sign out, even if delete fails
      // This ensures user is logged out regardless of backend result
      print('🚪 [AuthService] Signing out after deleteAccount...');
      await signOut();
    }
  }

  // Send OTP to email (for both login and signup)
  Future<void> sendOtp(String email) async {
    try {
      await _client.auth.signInWithOtp(email: email, emailRedirectTo: null);
    } catch (e) {
      throw Exception('Failed to send OTP: $e');
    }
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

    // ⭐ IMPORTANT: Update user metadata IMMEDIATELY after verifyOTP
    // This ensures auth state change picks up the correct preferences
    // instead of default values from Supabase
    final userId = response.user?.id;
    if (userId != null && (languageLevel != null || englishVariant != null || displayName != null)) {
      try {
        await updateUserPreferences(
          userId: userId,
          email: email,
          displayName: displayName,
          languageLevel: languageLevel,
          englishVariant: englishVariant,
        );
        print('✅ [AuthService] Updated user preferences immediately after OTP verify: level=$languageLevel, variant=$englishVariant');
      } catch (e) {
        // Don't fail the login if preference update fails
        print('⚠️ [AuthService] Failed to update preferences immediately: $e');
      }
    }

    // เช็ค isNewUser จาก users table โดยตรง
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

    // ⭐ IMPORTANT: Refresh session to get updated metadata
    await _client.auth.refreshSession();
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

  // Check if email already exists in the system
  Future<bool> checkEmailExists(String email) async {
    try {
      final response = await _client
          .from('users')
          .select('id')
          .eq('email', email)
          .maybeSingle();
      return response != null;
    } catch (e) {
      // If error occurs, assume email doesn't exist to allow signup
      return false;
    }
  }

  // Merge guest preferences into existing user account
  // Preferences: overwrite with guest values
  // Vocabulary: upload local vocabularies to cloud
  Future<void> mergeGuestPreferences({
    required String userId,
    required String email,
    String? displayName,
    String? languageLevel,
    String? englishVariant,
    int? termsVersion,
    // Optional services for vocabulary merge
    dynamic hiveService,
    dynamic vocabularySyncService,
  }) async {
    final data = {
      'id': userId,
      'email': email,
      // Overwrite with guest preferences
      if (displayName != null) 'display_name': displayName,
      if (languageLevel != null) 'language_level': languageLevel,
      if (englishVariant != null) 'english_variant': englishVariant,
      if (termsVersion != null) 'terms_version': termsVersion,
    };

    // Update users table
    await _client.from('users').update(data).eq('id', userId);

    // Update auth user metadata
    await _client.auth.updateUser(
      UserAttributes(
        data: {
          if (displayName != null) 'display_name': displayName,
          if (languageLevel != null) 'language_level': languageLevel,
          if (englishVariant != null) 'english_variant': englishVariant,
          if (termsVersion != null) 'terms_version': termsVersion,
        },
      ),
    );

    // ⭐ IMPORTANT: Refresh session to get updated metadata
    await _client.auth.refreshSession();

    // Merge vocabulary if services are provided
    if (hiveService != null && vocabularySyncService != null) {
      try {
        // First, fetch existing vocabularies from cloud to avoid duplicates
        final cloudVocabs = await vocabularySyncService.fetchFromCloud();
        final cloudVocabIds = {for (var v in cloudVocabs) v.id};

        // Get local vocabularies
        final localVocabs = await hiveService.getAllVocabulary();

        // Filter: only upload vocabularies that don't exist in cloud yet
        final newVocabs = localVocabs.where((vocab) => !cloudVocabIds.contains(vocab.id)).toList();

        if (newVocabs.isNotEmpty) {
          await vocabularySyncService.batchUpload(newVocabs);
        }
        // Clear local vocabularies only after successful upload
        await hiveService.clearAllVocabulary();
      } catch (e) {
        // Don't fail the whole merge process if vocab merge fails
        // Local vocabularies preserved for retry
      }
    }
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

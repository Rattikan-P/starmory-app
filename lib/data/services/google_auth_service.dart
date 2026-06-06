import 'dart:io';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GoogleAuthService {
  final SupabaseClient _client = Supabase.instance.client;

  GoogleSignIn get _googleSignIn => GoogleSignIn(
    clientId: Platform.isIOS
        ? dotenv.env['IOS_CLIENT']
        : dotenv.env['ANDROID_CLIENT'],
    serverClientId: dotenv.env['WEB_CLIENT'],
  );

  Future<bool> signInWithGoogle({bool forceAccountSelection = false}) async {
    try {
      print('🔍 [DEBUG] Google Sign In Started');
      print('🔍 [DEBUG] Platform: ${Platform.isIOS ? "iOS" : "Android"}');
      print('🔍 [DEBUG] Client ID: ${Platform.isIOS ? dotenv.env['IOS_CLIENT'] : dotenv.env['ANDROID_CLIENT']}');

      if (forceAccountSelection) {
        print('🔍 [DEBUG] Force account selection - signing out first');
        await _googleSignIn.signOut(); // force ถาม account ใหม่
      }

      print('🔍 [DEBUG] Calling GoogleSignIn.signIn()...');
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        print('❌ [DEBUG] User cancelled Google Sign In');
        return false;
      }

      print('✅ [DEBUG] Got Google user: ${googleUser.email}');
      print('🔍 [DEBUG] Getting authentication tokens...');

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      print('🔍 [DEBUG] ID Token length: ${idToken?.length ?? "NULL"}');
      print('🔍 [DEBUG] Access Token length: ${accessToken?.length ?? "NULL"}');

      if (idToken == null) {
        print('❌ [DEBUG] No ID token found');
        throw Exception('No ID token found');
      }

      print('🔍 [DEBUG] Calling Supabase signInWithIdToken...');
      await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      print('✅ [DEBUG] Google Sign In SUCCESS!');
      return true;
    } catch (e, st) {
      print('❌ [DEBUG] Error during Google sign in: $e');
      print('❌ [DEBUG] Stack trace: $st');
      rethrow;
    }
  }

  Future<void> signOutFromGoogle() async {
    try {
      await _googleSignIn.signOut();
      await _client.auth.signOut();
    } catch (e) {
      print('Error during Google sign out: $e');
    }
  }

  User? get currentUser => _client.auth.currentUser;
  bool get isLoggedIn => _client.auth.currentSession != null;
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;
}
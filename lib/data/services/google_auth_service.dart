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
      if (forceAccountSelection) {
        await _googleSignIn.signOut(); // force ถาม account ใหม่
      }

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return false;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null) throw Exception('No ID token found');

      await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      return true;
    } catch (e) {
      print('Error during Google sign in: $e');
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
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../clinic_client.dart';

bool get supportsGoogleAuth =>
    kIsWeb || defaultTargetPlatform == TargetPlatform.android;

final _initializeGoogle = GoogleSignIn.instance.initialize(
  serverClientId: '967121829158-0mdc05ppe4mqm66h10u3pp9suopjsh3k.apps.googleusercontent.com',
);

Future<String?> startGoogleAuth() async {
  final settings = await http
      .get(
        Uri.parse('$clinicUrl/auth/v1/settings'),
        headers: {'apikey': clinicPublishableKey},
      )
      .timeout(const Duration(seconds: 10));
  if (settings.statusCode != 200) throw StateError('Auth settings unavailable');
  if (jsonDecode(settings.body)['external']['google'] != true) {
    return 'Google sign-in is not available yet. Use email to continue.';
  }
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await _initializeGoogle;
    try {
      final account = await GoogleSignIn.instance.authenticate();
      final token = account.authentication.idToken;
      if (token == null) return 'Google did not return an ID token. Try again.';
      await db.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: token,
      );
      return null;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
  }
  final launched = await db.auth.signInWithOAuth(
    OAuthProvider.google,
    redirectTo: Uri.base.origin,
  );
  return launched ? null : 'Could not open Google sign-in. Please try again.';
}

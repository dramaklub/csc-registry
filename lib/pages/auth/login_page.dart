import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../clinic_client.dart';
import 'auth_field_builder.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({
    super.key,
    required this.email,
    required this.password,
    required this.field,
    required this.onReset,
  });
  final TextEditingController email, password;
  final AuthFieldBuilder field;
  final VoidCallback? onReset;
  static Future<void> signIn(String email, String password) async {
    await db.auth.signInWithPassword(email: email.trim(), password: password);
  }

  static Future<void> resetPassword(String email) =>
      db.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: !kIsWeb && defaultTargetPlatform == TargetPlatform.android
            ? 'cce-skills-clinic://auth/recovery'
            : null,
      );
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      field(
        label: 'UMindanao email',
        controller: email,
        hint: 'name@umindanao.edu.ph',
      ),
      SizedBox(height: 16),
      field(
        label: 'Password',
        controller: password,
        hint: '••••••••',
        secret: true,
      ),
      SizedBox(height: 4),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: onReset,
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF30313A),
            padding: EdgeInsets.zero,
            minimumSize: const Size(48, 48),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            'Forgot password?',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    ],
  );
}

import 'package:flutter/material.dart';

import '../../clinic_client.dart';
import 'auth_field_builder.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterPage extends StatelessWidget {
  const RegisterPage({
    super.key,
    required this.first,
    required this.last,
    required this.email,
    required this.password,
    required this.confirmPassword,
    required this.field,
  });
  final TextEditingController first, last, email, password, confirmPassword;
  final AuthFieldBuilder field;
  static Future<AuthResponse> signUp(
    String email,
    String password,
    String first,
    String last,
  ) => db.auth.signUp(
    email: email.trim(),
    password: password,
    data: {'first_name': first.trim(), 'last_name': last.trim()},
  );
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: field(label: 'First name', controller: first),
          ),
          SizedBox(width: 16),
          Expanded(
            child: field(label: 'Last name', controller: last),
          ),
        ],
      ),
      SizedBox(height: 16),
      field(
        label: 'UMindanao email',
        controller: email,
        hint: 'name@umindanao.edu.ph',
      ),
      SizedBox(height: 16),
      field(label: 'Password', controller: password, secret: true),
      const SizedBox(height: 16),
      field(
        label: 'Confirm password',
        controller: confirmPassword,
        secret: true,
      ),
    ],
  );
}

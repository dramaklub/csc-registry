import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({
    super.key,
    required this.save,
    required this.onSaved,
  });
  final Future<void> Function(String password) save;
  final VoidCallback onSaved;
  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final form = GlobalKey<FormState>();
  final password = TextEditingController();
  bool busy = false;

  @override
  void dispose() {
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      await widget.save(password.text);
      if (mounted) widget.onSaved();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is AuthException
                  ? error.message
                  : 'Could not update your password. Try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Set a new password')),
    body: SafeArea(
      child: Form(
        key: form,
        child: AutofillGroup(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              TextFormField(
                controller: password,
                obscureText: true,
                enabled: !busy,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'New password'),
                validator: (v) => (v ?? '').trim().isEmpty || v!.length < 8
                    ? 'Use at least 8 characters'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                obscureText: true,
                enabled: !busy,
                decoration: const InputDecoration(
                  labelText: 'Confirm new password',
                ),
                onFieldSubmitted: (_) => submit(),
                validator: (v) =>
                    v != password.text ? 'Passwords do not match' : null,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: busy ? null : submit,
                child: Text(busy ? 'Saving…' : 'Save password'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

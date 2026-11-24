import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../clinic_client.dart';

class RoleSetup extends StatefulWidget {
  const RoleSetup({
    super.key,
    required this.onSignOut,
    required this.onComplete,
  });
  final Future<void> Function() onSignOut;
  final VoidCallback onComplete;
  @override
  State<RoleSetup> createState() => _RoleSetupState();
}

class _RoleSetupState extends State<RoleSetup> {
  String? selected, error;
  bool busy = false;
  Future<void> save() async {
    if (selected == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await db.rpc('complete_onboarding', params: {'chosen_role': selected});
      if (mounted) widget.onComplete();
    } on PostgrestException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) setState(() => error = 'Unable to save. Please try again.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Welcome to Skills Clinic')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'How will you use Skills Clinic?',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            const Text(
              'Choose your role once to finish setting up your account.',
            ),
            const SizedBox(height: 24),
            for (final role in ['mentee', 'mentor'])
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: OutlinedButton(
                  onPressed: busy
                      ? null
                      : () => setState(() => selected = role),
                  child: Text(
                    '${selected == role ? "✓ " : ""}${role == "mentee" ? "Mentee — request help" : "Mentor — help students"}',
                  ),
                ),
              ),
            const Text(
              'Your choice is permanent. Mentor access requires clinic approval.',
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(error!),
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: busy || selected == null ? null : save,
              child: Text(busy ? 'Saving…' : 'Continue'),
            ),
            TextButton(
              onPressed: busy ? null : widget.onSignOut,
              child: const Text('Sign out'),
            ),
          ],
        ),
      ),
    ),
  );
}

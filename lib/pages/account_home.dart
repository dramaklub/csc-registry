import 'request_topic_page.dart';
import '../widgets/clinic_feedback.dart';

import 'package:flutter/material.dart';

import '../clinic_client.dart';
import '../appointment_repository.dart';
import '../widgets/clinic_loader.dart';
import 'mentee_home.dart';
import 'role_setup.dart';

class AccountHome extends StatefulWidget {
  const AccountHome({super.key});
  @override
  State<AccountHome> createState() => _AccountHomeState();
}

class _AccountHomeState extends State<AccountHome> {
  late Future<Map<String, dynamic>> profile;
  bool signingOut = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  void load() {
    profile = db
        .from('users')
        .select()
        .eq('id', db.auth.currentUser!.id)
        .single();
  }

  Future<void> signOut() async {
    if (signingOut) return;
    setState(() => signingOut = true);
    try {
      await db.auth.signOut();
    } catch (_) {
      if (mounted) {
        setState(() => signingOut = false);
        showClinicToast(context, 'Unable to sign out. Please retry.');
      }
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: profile,
    builder: (context, snapshot) {
      if (signingOut) return const ClinicTransition('Logging you out…');
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const ClinicTransition('Logging you in…');
      }
      final user = snapshot.data;
      if (user != null && user['role'] == null) {
        return RoleSetup(onSignOut: signOut, onComplete: () => setState(load));
      }
      if (user?['role'] == 'mentee') {
        return MenteeHome(
          name: [user!['first_name'], user['last_name']]
              .whereType<String>()
              .map((name) => name.trim())
              .where((name) => name.isNotEmpty)
              .join(' '),
          newRequest: (context) => Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => RequestTopicPage(AppointmentRepository(db)),
            ),
          ),
          watchFeed: AppointmentRepository(db).watchFeed,
          onSignOut: signOut,
        );
      }
      return Scaffold(
        appBar: AppBar(
          title: Text(
            user?['role'] == 'mentor' ? 'Mentor lobby' : 'My appointments',
          ),
          actions: [
            IconButton(
              onPressed: signOut,
              icon: const Icon(Icons.logout),
              tooltip: 'Sign out',
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: snapshot.hasError
              ? Column(
                  children: [
                    const Text('Unable to load your profile.'),
                    TextButton(
                      onPressed: () => setState(load),
                      child: const Text('Retry'),
                    ),
                  ],
                )
              : user == null
              ? const Center(child: ClinicLoader())
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hello, ${user['first_name']}',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 16),
                    Text('Account role: ${user['role']}'),
                    const SizedBox(height: 16),
                    const Text(
                      'Your account is connected. Appointment screens are the next development step.',
                    ),
                  ],
                ),
        ),
      );
    },
  );
}

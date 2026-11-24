import 'widgets/clinic_feedback.dart';
import 'package:flutter/material.dart';

import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'clinic_client.dart';
import 'pages/auth/auth_screen.dart';
import 'pages/account_home.dart';
import 'pages/auth/reset_password_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: clinicUrl, anonKey: clinicPublishableKey);
  runApp(const ClinicApp());
}

class ClinicApp extends StatelessWidget {
  const ClinicApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Skills Clinic',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF53179C),
        primary: const Color(0xFF53179C),
        surface: const Color(0xFFF8F8F8),
      ),
      scaffoldBackgroundColor: const Color(0xFFF8F8F8),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF5B3F91),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFB9B0CC),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF594091),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    ),
    home: const _AuthGate(),
  );
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();
  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  final auth = Supabase.instance.client.auth;
  late final StreamSubscription<AuthState> subscription;
  String? recoveringUser;

  @override
  void initState() {
    super.initState();
    subscription = auth.onAuthStateChange.listen(
      (state) {
        if (!mounted) return;
        setState(() {
          if (state.event == AuthChangeEvent.passwordRecovery) {
            recoveringUser = state.session?.user.id;
          } else if (state.session?.user.id != recoveringUser) {
            recoveringUser = null;
          }
        });
      },
      onError: (Object error) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          showClinicToast(context, 'Could not verify your session. For password recovery, request a fresh link and open it on this phone.');
        });
        WidgetsBinding.instance.ensureVisualUpdate();
      },
    );
  }

  @override
  void dispose() {
    subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = auth.currentUser;
    if (user == null) return const AuthScreen();
    if (user.id == recoveringUser) {
      return ResetPasswordPage(
        key: ValueKey(user.id),
        save: (password) async {
          await auth.updateUser(UserAttributes(password: password));
        },
        onSaved: () {
          showClinicToast(context, 'Password updated.');
          setState(() => recoveringUser = null);
        },
      );
    }
    return AccountHome(key: ValueKey(user.id));
  }
}

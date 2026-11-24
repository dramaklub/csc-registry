import 'package:flutter/material.dart';

import 'clinic_loader.dart';

class ClinicTransition extends StatelessWidget {
  const ClinicTransition(this.message, {super.key});
  final String message;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFCCB8DD),
    body: SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ClinicLoader(),
            const SizedBox(height: 20),
            Text(message, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    ),
  );
}

void showClinicToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..removeCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF39274E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        content: Row(
          children: [
            Image.asset('assets/skills-clinic-mark.png', width: 26, height: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
}

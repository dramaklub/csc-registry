import 'package:flutter/material.dart';

class ClinicLoader extends StatelessWidget {
  const ClinicLoader({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading Skills Clinic',
    liveRegion: true,
    child: ExcludeSemantics(
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: const Color(0xFF53179C),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.square(
              dimension: 52,
              child: CircularProgressIndicator(
                value: MediaQuery.disableAnimationsOf(context) ? 1 : null,
                color: const Color(0xFFFFDE59),
                backgroundColor: const Color(0xFF9471BB),
                strokeWidth: 2.5,
              ),
            ),
            Image.asset('assets/skills-clinic-mark.png', width: 30, height: 30),
          ],
        ),
      ),
    ),
  );
}

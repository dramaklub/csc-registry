import 'package:flutter/material.dart';

final authFieldFill = WidgetStateColor.resolveWith(
  (states) => states.contains(WidgetState.error)
      ? const Color(0xFFFBEAEC)
      : const Color(0xFFF0EDF3),
);
const authErrorStyle = TextStyle(color: Color(0xFF942C40));
final authErrorBorder = OutlineInputBorder(
  borderRadius: BorderRadius.circular(14),
  borderSide: const BorderSide(color: Color(0xFFAC5363)),
);

InputDecoration recoveryFieldDecoration(String label) => InputDecoration(
  labelText: label,
  filled: true,
  fillColor: authFieldFill,
  errorStyle: authErrorStyle,
  errorBorder: authErrorBorder,
  focusedErrorBorder: authErrorBorder,
);

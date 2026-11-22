import 'package:flutter/material.dart';

typedef AuthFieldBuilder = Widget Function({
  required String label,
  required TextEditingController controller,
  String? hint,
  bool secret,
});

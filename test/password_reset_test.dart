import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theregistry/pages/auth/reset_password_page.dart';

void main() {
  testWidgets('recovery validates confirmation and saves before finishing', (
    tester,
  ) async {
    String? saved;
    var finished = false;
    await tester.pumpWidget(
      MaterialApp(
        home: ResetPasswordPage(
          save: (value) async {
            saved = value;
          },
          onSaved: () => finished = true,
        ),
      ),
    );
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.first, 'example-new-password');
    await tester.enterText(fields.last, 'different');
    await tester.tap(find.text('Save password'));
    await tester.pump();
    expect(find.text('Passwords do not match'), findsOneWidget);
    expect(saved, isNull);
    await tester.enterText(fields.last, 'example-new-password');
    await tester.tap(find.text('Save password'));
    await tester.pump();
    expect(saved, 'example-new-password');
    expect(finished, isTrue);
  });
}

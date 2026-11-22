import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theregistry/auth_screen.dart';

void main() {
  testWidgets('Phone login stays usable with the keyboard open', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: AuthScreen()));
    expect(find.byType(TextFormField), findsNothing);
    await tester.drag(find.text('Swipe up to sign in'), const Offset(0, -160));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    final loginPosition = tester.getTopLeft(find.byType(FilledButton));
    await tester.tap(find.text('Forgot password?'));
    await tester.pump();
    expect(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.text('Enter your UMindanao email first.'),
      ),
      findsOneWidget,
    );
    expect(tester.getTopLeft(find.byType(FilledButton)), loginPosition);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 300));
    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(2));
    await tester.enterText(fields.last, 'example');
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(
      tester.widget<EditableText>(find.byType(EditableText).last).obscureText,
      isFalse,
    );
    tester.view.viewInsets = const FakeViewPadding(bottom: 250);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.dragFrom(const Offset(28, 275), const Offset(0, -150));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.pump();
    await tester.tap(find.text('Login'));
    await tester.pump();
    expect(find.text('Enter your umindanao email'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Registration and return to login are reachable', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AuthScreen()));
    await tester.tap(find.text('Swipe up to sign in'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.ensureVisible(find.textContaining('Register here'));
    await tester.tap(find.textContaining('Register here'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Confirm password'), findsOneWidget);
    final back = find.textContaining('Back to sign in');
    await tester.ensureVisible(back);
    await tester.tap(back);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(TextFormField), findsNWidgets(2));
  });
}

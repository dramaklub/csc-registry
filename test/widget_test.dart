import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theregistry/auth_screen.dart';

void main() {
  testWidgets(
    'both auth panels fit a portrait phone with the keyboard closed',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 740);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: AuthScreen()));
      await tester.tap(find.text('Swipe up or tap to sign in'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      for (final isRegistration in [false, true]) {
        if (isRegistration) {
          await tester.tap(find.text('Sign up'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
        }
        final scroll = tester.state<ScrollableState>(
          find
              .descendant(
                of: find.byType(SingleChildScrollView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(scroll.position.maxScrollExtent, 0);
        expect(find.text('Continue with Google').hitTestable(), findsOneWidget);
      }
    },
  );
  testWidgets('tap the landing area and pull the form down to close it', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AuthScreen()));
    await tester.tapAt(const Offset(400, 120));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(TextFormField), findsNWidgets(2));
    await tester.dragFrom(
      tester.getTopLeft(find.byType(SingleChildScrollView)) +
          const Offset(8, 12),
      const Offset(0, 150),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(TextFormField), findsNothing);
  });
  testWidgets('Phone login stays usable with the keyboard open', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: AuthScreen()));
    expect(find.byType(TextFormField), findsNothing);
    await tester.drag(
      find.text('Swipe up or tap to sign in'),
      const Offset(0, -160),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    final loginPosition = tester.getTopLeft(find.byType(FilledButton));
    await tester.tap(find.text('Forgot password?'));
    await tester.pump();
    expect(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.text('Enter your email first.'),
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
    await tester.tap(find.text('Log In'));
    await tester.pump();
    expect(
      tester
          .state<FormFieldState<String>>(find.byType(TextFormField).first)
          .errorText,
      'Enter your email',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Registration and return to login are reachable', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AuthScreen()));
    await tester.tap(find.text('Swipe up or tap to sign in'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.ensureVisible(find.text('Sign up'));
    await tester.tap(find.text('Sign up'));
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

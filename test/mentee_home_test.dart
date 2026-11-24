import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theregistry/appointment_feed.dart';
import 'package:theregistry/pages/mentee_home.dart';

void main() {
  testWidgets('mentee sees real requests and history and can start a request', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 740);
    addTearDown(tester.view.reset);
    final feed = AppointmentFeed.fromJson([
      for (final status in ['pending', 'completed'])
        {
          'id': status,
          'status': status,
          'topic': status == 'pending' ? 'Algebra' : 'Databases',
          'section': status == 'pending' ? 'pending' : 'history',
          'mentee_name': 'Sam',
          'created_at': '2026-11-23T12:00:00Z',
          'mentor_ready': false,
          'mentee_ready': false,
        },
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: MenteeHome(
          name: 'Sam',
          watchFeed: () => Stream.value(feed),
          newRequest: (_) async => false,
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('01'), findsOneWidget);
    expect(find.text('Algebra'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.ancestor(
              of: find.text('New request'),
              matching: find.byType(FilledButton),
            ),
          )
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('Databases'), findsOneWidget);
    expect(find.text('Algebra'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

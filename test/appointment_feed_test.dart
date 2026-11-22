import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:theregistry/appointment_feed.dart';
import 'package:theregistry/appointment_repository.dart';

void main() {
  test(
    'an open lobby drops a claimed request and reopening fetches fresh data',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      var rows = <Map<String, dynamic>>[
        {
          'id': 'request',
          'topic': 'Git',
          'mentee_name': 'Student',
          'status': 'pending',
          'section': 'open',
          'is_star': true,
          'created_at': '2026-11-01T00:00:00Z',
          'mentor_ready': false,
          'mentee_ready': false,
        },
      ];
      server.listen((request) async {
        expect(request.uri.path, '/rest/v1/rpc/appointment_feed');
        await request.drain<void>();
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(rows));
        await request.response.close();
      });
      final client = SupabaseClient('http://127.0.0.1:${server.port}', 'test');
      addTearDown(client.dispose);
      final repo = AppointmentRepository(client);
      final snapshots = StreamIterator(
        repo.watchFeed(interval: const Duration(milliseconds: 20)),
      );
      addTearDown(snapshots.cancel);
      expect(await snapshots.moveNext(), isTrue);
      expect(
        snapshots.current.section(AppointmentSection.open).single.topic,
        'Git',
      );
      rows = [];
      expect(await snapshots.moveNext(), isTrue);
      expect(snapshots.current.items, isEmpty);
      await snapshots.cancel();
      expect((await repo.watchFeed().first).items, isEmpty);
    },
  );
}

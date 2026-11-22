import 'package:supabase_flutter/supabase_flutter.dart';

import 'appointment_feed.dart';
import 'appointment_detail.dart';
import 'session_history.dart';

/// Lifecycle writes always go through the server's validated transaction.
class AppointmentRepository {
  AppointmentRepository(this.client);
  final SupabaseClient client;

  Future<List<String>> loadTopics() async {
    final rows = await client.from('topics').select('name').order('name');
    final names = rows.map((row) => row['name'] as String).toList();
    if (names.remove('Other')) names.add('Other');
    return names;
  }

  Future<List<EligibleMentor>> loadEligibleMentors(String topic) async {
    final rows = await client.rpc<List<dynamic>>(
      'eligible_mentors',
      params: {'topic_name': topic},
    );
    return rows
        .cast<Map<String, dynamic>>()
        .map(EligibleMentor.fromJson)
        .toList();
  }

  /// Missing rooms and rooms hidden by row-level security both return null.
  Future<AppointmentDetail?> loadDetail(String appointmentId) async {
    final row = await client.rpc<Map<String, dynamic>?>(
      'appointment_detail',
      params: {'room_id': appointmentId},
    );
    return row == null ? null : AppointmentDetail.fromJson(row);
  }

  Future<AppointmentFeed> loadFeed() async => AppointmentFeed.fromJson(
    await client.rpc<List<dynamic>>('appointment_feed'),
  );

  Future<SessionHistory?> loadSessionHistory(String appointmentId) async {
    final row = await client.rpc<Map<String, dynamic>?>(
      'session_history_detail',
      params: {'room_id': appointmentId},
    );
    return row == null ? null : SessionHistory.fromJson(row);
  }

  /// Fetch immediately, then refresh the entire role-scoped list while subscribed.
  /// A refetch also removes requests that have become invisible to this user.
  Stream<AppointmentFeed> watchFeed({
    Duration interval = const Duration(seconds: 5),
  }) {
    if (interval <= Duration.zero) {
      throw ArgumentError.value(interval, 'interval');
    }
    Stream<void> ticks() async* {
      yield null;
      yield* Stream<void>.periodic(interval, (_) {});
    }

    return ticks().asyncMap((_) => loadFeed());
  }

  Stream<List<Map<String, dynamic>>> watchAppointments() => client
      .from('appointments')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false);

  Stream<List<Map<String, dynamic>>> watchMentors(String appointmentId) =>
      client
          .from('participating_mentors')
          .stream(primaryKey: ['id'])
          .eq('appointment_id', appointmentId);

  Future<String> act(String action, Map<String, dynamic> payload) async =>
      await client.rpc(
        'appointment_action',
        params: {'action': action, 'payload': payload},
      ) as String;

  Future<String> create({
    required String topic,
    String? customTopic,
    String? targetMentorId,
    DateTime? scheduledAt,
    String? courseCode,
    String? professorName,
    bool isStar = false,
  }) => act('create', {
    'topic': topic,
    'custom_topic': customTopic,
    'target_mentor_id': targetMentorId,
    'scheduled_at': scheduledAt?.toUtc().toIso8601String(),
    'course_code': courseCode,
    'professor_name': professorName,
    'is_star': isStar,
  });

  Future<String> claim(String id) => act('claim', {'appointment_id': id});
  Future<String> join(String id) => act('join', {'appointment_id': id});
  Future<String> ready(String id) => act('ready', {'appointment_id': id});

  Future<({String token, DateTime expiresAt})> issueQr(
    String appointmentId,
  ) async {
    final code = await client.rpc<Map<String, dynamic>>(
      'issue_appointment_qr',
      params: {'room_id': appointmentId},
    );
    return (
      token: code['token'] as String,
      expiresAt: DateTime.parse(code['expires_at'] as String),
    );
  }

  Future<String> scanQr(String appointmentId, String token) async =>
      await client.rpc<String>(
        'scan_appointment_qr',
        params: {'room_id': appointmentId, 'qr_token': token},
      );
  Future<String> cancel(String id) => act('cancel', {'appointment_id': id});
  Future<String> retarget(String id, String? mentorId) =>
      act('retarget', {'appointment_id': id, 'target_mentor_id': mentorId});
  Future<String> finalize(
    String id,
    String notes,
    int rating, {
    String? remedialScore,
  }) => act('finalize', {
    'appointment_id': id,
    'notes': notes,
    'rating': rating,
    'remedial_score': remedialScore,
  });
  Future<String> feedback(String id, int rating, {String? notes}) =>
      act('feedback', {'appointment_id': id, 'rating': rating, 'notes': notes});
}

import 'appointment_feed.dart';

class EligibleMentor {
  EligibleMentor.fromJson(Map<String, dynamic> row)
    : id = row['id'] as String,
      name = row['name'] as String,
      specialties = List<String>.unmodifiable(row['specialties'] as List);
  final String id, name;
  final List<String> specialties;
}

class RoomMentor {
  RoomMentor.fromJson(Map<String, dynamic> row)
    : id = row['id'] as String,
      name = row['name'] as String,
      isPrimary = row['is_primary'] as bool;
  final String id, name;
  final bool isPrimary;
}

class AppointmentDetail {
  AppointmentDetail.fromJson(Map<String, dynamic> row)
    : id = row['id'] as String,
      topic = row['topic'] as String,
      customTopic = row['custom_topic'] as String?,
      status = parseAppointmentStatus(row['status'] as String),
      menteeId = row['mentee_id'] as String,
      menteeName = row['mentee_name'] as String,
      targetMentorId = row['target_mentor_id'] as String?,
      courseCode = row['course_code'] as String?,
      professorName = row['professor_name'] as String?,
      scheduledAt = row['scheduled_at'] == null
          ? null
          : DateTime.parse(row['scheduled_at'] as String),
      menteeReady = row['mentee_ready'] as bool,
      mentorReady = row['mentor_ready'] as bool,
      isStar = row['is_star'] as bool?,
      canClaim = row['can_claim'] as bool,
      canJoin = row['can_join'] as bool,
      canReady = row['can_ready'] as bool,
      canFinalize = row['can_finalize'] as bool,
      mentors = List.unmodifiable(
        (row['mentors'] as List).cast<Map<String, dynamic>>().map(
          RoomMentor.fromJson,
        ),
      );
  final String id, topic, menteeId, menteeName;
  final String? customTopic, targetMentorId, courseCode, professorName;
  final AppointmentStatus status;
  final DateTime? scheduledAt;
  final bool menteeReady, mentorReady, canClaim, canJoin, canReady, canFinalize;
  final bool? isStar;
  final List<RoomMentor> mentors;
}

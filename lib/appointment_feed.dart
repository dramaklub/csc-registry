enum AppointmentSection { pending, open, requested, active, history }

enum AppointmentStatus { pending, accepted, inProgress, completed, cancelled }

AppointmentStatus parseAppointmentStatus(String value) => value == 'in_progress'
    ? AppointmentStatus.inProgress
    : AppointmentStatus.values.byName(value);

class AppointmentSummary {
  AppointmentSummary.fromJson(Map<String, dynamic> row)
    : id = row['id'] as String,
      topic = row['topic'] as String,
      menteeName = row['mentee_name'] as String,
      mentorName = row['mentor_name'] as String?,
      createdAt = DateTime.parse(row['created_at'] as String),
      scheduledAt = DateTime.tryParse(row['scheduled_at'] as String? ?? ''),
      section = AppointmentSection.values.byName(row['section'] as String),
      status = parseAppointmentStatus(row['status'] as String),
      mentorReady = row['mentor_ready'] as bool,
      menteeReady = row['mentee_ready'] as bool,
      notes = row['notes'] as String?,
      isStar = row['is_star'] as bool?;

  final String id, topic, menteeName;
  final String? mentorName, notes;
  final DateTime createdAt;
  final DateTime? scheduledAt;
  final AppointmentSection section;
  final AppointmentStatus status;
  final bool mentorReady, menteeReady;
  final bool? isStar;
}

class AppointmentFeed {
  AppointmentFeed.fromJson(List<dynamic> rows)
    : items = List.unmodifiable(
        rows.cast<Map<String, dynamic>>().map(AppointmentSummary.fromJson),
      );

  final List<AppointmentSummary> items;

  Iterable<AppointmentSummary> section(AppointmentSection section) =>
      items.where((item) => item.section == section);
}

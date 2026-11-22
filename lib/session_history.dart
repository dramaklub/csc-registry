class SessionHistory {
  SessionHistory.fromJson(Map<String, dynamic> row)
    : appointmentId = row['appointment_id'] as String,
      sharedNotes = row['shared_notes'] as String,
      isStar = row['is_star'] as bool?,
      remedialScore = row['remedial_score'] as String?,
      feedbackSubmitted = row['feedback_submitted'] as bool,
      feedbackNotes = row['feedback_notes'] as String?,
      canLeaveFeedback = row['can_leave_feedback'] as bool,
      ownRating = row['own_rating'] as int?;

  final String appointmentId, sharedNotes;
  final String? remedialScore, feedbackNotes;
  final bool? isStar;
  final bool feedbackSubmitted, canLeaveFeedback;
  final int? ownRating;
}

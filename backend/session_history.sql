-- Completed-room read using existing participant and rating policies.
create function public.session_history_detail(room_id uuid) returns jsonb
language sql stable security invoker set search_path='' as $$
  select jsonb_build_object(
    'appointment_id', a.id,
    'shared_notes', log.notes,
    'is_star', flag.is_star,
    'remedial_score', log.remedial_score,
    'feedback_submitted', feedback.id is not null,
    'feedback_notes', feedback.notes,
    'can_leave_feedback', a.mentee_id = (select auth.uid()) and feedback.id is null,
    'own_rating', rating.rating
  )
  from public.appointments a
  join public.session_logs log on log.appointment_id = a.id
  left join public.appointment_flags flag on flag.appointment_id = a.id
  left join public.mentee_feedback feedback on feedback.appointment_id = a.id
  left join public.session_ratings rating on rating.appointment_id = a.id
    and rating.author_id = (select auth.uid())
  where a.id = room_id and a.status = 'completed';
$$;
revoke all on function public.session_history_detail(uuid) from public, anon;
grant execute on function public.session_history_detail(uuid) to authenticated;

-- Each call reads a fresh, consistently ordered snapshot under the caller's RLS.
create function public.appointment_feed() returns jsonb
language sql stable security invoker set search_path = '' as $$
  select coalesce(jsonb_agg(to_jsonb(item) order by item.created_at desc, item.id), '[]'::jsonb)
  from (
    select a.id, a.status, a.created_at, a.scheduled_at,
      coalesce(a.custom_topic, a.topic) as topic,
      trim(concat_ws(' ', student.first_name, student.last_name)) as mentee_name,
      case when lead.id is not null then trim(concat_ws(' ', lead.first_name, lead.last_name)) end as mentor_name,
      a.mentee_ready, a.mentor_ready, logs.notes, flags.is_star,
      case when a.status in ('completed','cancelled') then 'history'
           when a.status <> 'pending' then 'active'
           when viewer.role = 'mentee' then 'pending'
           when a.target_mentor_id is not null then 'requested'
           else 'open' end as section
    from public.users viewer
    join public.appointments a on (
      (viewer.role = 'mentee' and a.mentee_id = viewer.id)
      or (viewer.role = 'mentor' and (
        (a.status = 'pending' and (a.target_mentor_id is null or a.target_mentor_id = viewer.id)
          and (a.topic = 'Other' or a.topic = any(viewer.specialties)))
        or exists (select 1 from public.participating_mentors mine
                   where mine.appointment_id = a.id and mine.mentor_id = viewer.id)
      ))
    )
    join public.users student on student.id = a.mentee_id
    left join public.participating_mentors pm on pm.appointment_id = a.id and pm.is_primary
    left join public.users lead on lead.id = pm.mentor_id
    left join public.session_logs logs on logs.appointment_id = a.id
    left join public.appointment_flags flags on flags.appointment_id = a.id
    where viewer.id = (select auth.uid())
  ) item;
$$;
revoke all on function public.appointment_feed() from public, anon;
grant execute on function public.appointment_feed() to authenticated;

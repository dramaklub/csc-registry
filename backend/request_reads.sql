create function public.eligible_mentors(topic_name text)
returns table(id uuid, name text, specialties text[])
language sql stable security invoker set search_path='' as $$
  select u.id, trim(concat_ws(' ',u.first_name,u.last_name)), u.specialties
  from public.users u join public.topics t on t.name=topic_name
  where u.role='mentor' and (t.name='Other' or t.name=any(u.specialties))
  order by u.last_name,u.first_name,u.id;
$$;

create function public.appointment_detail(room_id uuid) returns jsonb
language sql stable security invoker set search_path='' as $$
  select jsonb_build_object(
    'id',a.id,'topic',a.topic,'custom_topic',a.custom_topic,'status',a.status,
    'mentee_id',a.mentee_id,'mentee_name',trim(concat_ws(' ',student.first_name,student.last_name)),
    'target_mentor_id',a.target_mentor_id,'scheduled_at',a.scheduled_at,
    'course_code',a.course_code,'professor_name',a.professor_name,
    'mentee_ready',a.mentee_ready,'mentor_ready',a.mentor_ready,'is_star',f.is_star,
    'mentors',coalesce((
      select jsonb_agg(jsonb_build_object('id',p.mentor_id,'name',trim(concat_ws(' ',u.first_name,u.last_name)),
        'is_primary',p.is_primary) order by p.is_primary desc,u.last_name,u.first_name,p.mentor_id)
      from public.participating_mentors p join public.users u on u.id=p.mentor_id
      where p.appointment_id=a.id
    ),'[]'::jsonb),
    'can_claim',viewer.role='mentor' and a.status='pending',
    'can_join',viewer.role='mentor' and mine.id is null and a.status in ('accepted','in_progress'),
    'can_ready',a.status='accepted' and ((viewer.id=a.mentee_id and not a.mentee_ready)
       or (coalesce(mine.is_primary,false) and not a.mentor_ready)),
    'can_finalize',a.status='in_progress' and coalesce(mine.is_primary,false)
  )
  from public.appointments a join public.users student on student.id=a.mentee_id
  join public.users viewer on viewer.id=(select auth.uid())
  left join public.participating_mentors mine on mine.appointment_id=a.id and mine.mentor_id=viewer.id
  left join public.appointment_flags f on f.appointment_id=a.id
  where a.id=room_id;
$$;
revoke all on function public.eligible_mentors(text),public.appointment_detail(uuid) from public,anon;
grant execute on function public.eligible_mentors(text),public.appointment_detail(uuid) to authenticated;

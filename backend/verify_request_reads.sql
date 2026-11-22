begin;
do $verify$
declare
  m uuid := gen_random_uuid();   -- approved primary mentor
  rival uuid := gen_random_uuid();
  student uuid := gen_random_uuid();
  outsider uuid := gen_random_uuid();
  actor uuid;
  topic_name text := 'Programming fundamentals';
  room uuid;
  targeted uuid;
  row_data jsonb;
begin
  foreach actor in array array[m,rival,student,outsider] loop
    insert into auth.users(id,email,raw_user_meta_data)
    values(actor,actor::text||'@example.invalid',
      jsonb_build_object('first_name',case when actor=m then 'Lead' else 'Student' end));
    if actor in (m,rival) then
      insert into private.mentor_approvals(email) values(actor::text||'@example.invalid');
    end if;
    set local role authenticated;
    perform set_config('request.jwt.claim.sub',actor::text,true);
    perform public.complete_onboarding(case when actor in (m,rival) then 'mentor' else 'mentee' end);
    reset role;
  end loop;
  update public.users set specialties=array[topic_name] where id=m;
  set local role authenticated;
  perform set_config('request.jwt.claim.sub',student::text,true);
  if not exists(select 1 from public.topics where name=topic_name) then raise exception 'Missing topic'; end if;
  if not exists(select 1 from public.eligible_mentors(topic_name) where id=m)
     or exists(select 1 from public.eligible_mentors(topic_name) where id=rival)
     or not exists(select 1 from public.eligible_mentors('Other') where id=rival)
     or exists(select 1 from public.eligible_mentors('Other') where id=student)
     or exists(select 1 from public.eligible_mentors('Nonexistent test topic'))
     then raise exception 'Picker mismatch'; end if;
  begin
    perform public.appointment_action('create',jsonb_build_object('topic',topic_name,'target_mentor_id',rival));
    raise exception 'Invalid mentor accepted';
  exception when raise_exception then
    if sqlerrm <> 'Mentor is not eligible for topic' then raise; end if;
  end;
  targeted := public.appointment_action('create',jsonb_build_object('topic','Other','custom_topic','Custom topic','target_mentor_id',rival));
  if not coalesce(public.appointment_detail(targeted) @> '{"custom_topic":"Custom topic"}',false) then raise exception 'Custom topic missing'; end if;
  room := public.appointment_action('create',jsonb_build_object('topic',topic_name,'target_mentor_id',m,'is_star',true,'course_code','CS101','professor_name','Test professor','scheduled_at','2026-12-01T00:00:00Z'));
  row_data := public.appointment_detail(room);
  if not coalesce(row_data @> '{"status":"pending","is_star":null,"course_code":"CS101","professor_name":"Test professor","mentors":[]}',false)
     or (row_data->>'scheduled_at')::timestamptz is distinct from '2026-12-01T00:00:00Z'::timestamptz then raise exception 'Request metadata mismatch'; end if;
  perform set_config('request.jwt.claim.sub',outsider::text,true);
  if public.appointment_detail(room) is not null then raise exception 'Unrelated mentee saw room'; end if;
  perform set_config('request.jwt.claim.sub',rival::text,true);
  if public.appointment_detail(room) is not null then raise exception 'Uninvited mentor saw pending request'; end if;
  perform set_config('request.jwt.claim.sub',m::text,true);
  if not coalesce(public.appointment_detail(room) @> '{"can_claim":true,"is_star":true}',false) then raise exception 'Claim unavailable'; end if;
  perform public.appointment_action('claim',jsonb_build_object('appointment_id',room));
  perform set_config('request.jwt.claim.sub',rival::text,true);
  if not coalesce(public.appointment_detail(room) @> '{"can_join":true,"can_ready":false}',false) then raise exception 'Join unavailable'; end if;
  perform public.appointment_action('join',jsonb_build_object('appointment_id',room));
  if not coalesce(public.appointment_detail(room) @> '{"can_join":false,"can_ready":false}',false) then raise exception 'Secondary mentor actions incorrect'; end if;
  foreach actor in array array[m,student] loop
    perform set_config('request.jwt.claim.sub',actor::text,true);
    row_data := public.appointment_detail(room);
    if not coalesce(row_data @> '{"can_ready":true,"status":"accepted"}',false)
       or (row_data->'mentors'->0->>'id')::uuid is distinct from m
       or (row_data->'mentors'->1->>'id')::uuid is distinct from rival then raise exception 'Participant mismatch'; end if;
    perform public.appointment_action('ready',jsonb_build_object('appointment_id',room));
  end loop;
  foreach actor in array array[m,student,rival] loop
    perform set_config('request.jwt.claim.sub',actor::text,true);
    if not coalesce(public.appointment_detail(room) @> jsonb_build_object('status','in_progress','mentor_ready',true,'mentee_ready',true,'can_finalize',actor=m),false)
      then raise exception 'Active session actions incorrect'; end if;
  end loop;
end $verify$;
rollback;
select 'Request selection and room detail passed' as result;

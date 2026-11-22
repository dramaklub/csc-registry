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
  feed jsonb;
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
  room := public.appointment_action('create',jsonb_build_object('topic',topic_name,'is_star',true));
  targeted := public.appointment_action('create',jsonb_build_object('topic',topic_name,'target_mentor_id',m));
  feed := public.appointment_feed();
  if not feed @> jsonb_build_array(jsonb_build_object('id',room,'section','pending','is_star',null))
    then raise exception 'Missing private mentee summary'; end if;
  perform set_config('request.jwt.claim.sub',outsider::text,true);
  if public.appointment_feed() <> '[]'::jsonb then raise exception 'Unrelated mentee saw appointments'; end if;
  perform set_config('request.jwt.claim.sub',rival::text,true);
  if public.appointment_feed() @> jsonb_build_array(jsonb_build_object('id',room))
    then raise exception 'Ineligible mentor saw open request'; end if;
  update public.users set specialties=array[topic_name] where id=rival;
  feed := public.appointment_feed();
  if not feed @> jsonb_build_array(jsonb_build_object('id',room,'section','open'))
    or feed @> jsonb_build_array(jsonb_build_object('id',targeted))
    then raise exception 'Open or targeted eligibility failed'; end if;
  perform set_config('request.jwt.claim.sub',m::text,true);
  if not public.appointment_feed() @> jsonb_build_array(jsonb_build_object('id',targeted,'section','requested'))
    then raise exception 'Missing direct request'; end if;
  perform public.appointment_action('claim',jsonb_build_object('appointment_id',room));
  perform set_config('request.jwt.claim.sub',rival::text,true);
  begin
    perform public.appointment_action('claim',jsonb_build_object('appointment_id',room));
    raise exception 'Second claim succeeded';
  exception when raise_exception then
    if sqlerrm <> 'Request unavailable or not eligible' then raise; end if;
  end;
  if public.appointment_feed() @> jsonb_build_array(jsonb_build_object('id',room))
    then raise exception 'Claimed request remained in other lobby'; end if;
  foreach actor in array array[m,student] loop
    perform set_config('request.jwt.claim.sub',actor::text,true);
    if not public.appointment_feed() @> jsonb_build_array(jsonb_build_object(
       'id',room,'status','accepted','section','active','mentor_name','Lead'))
      then raise exception 'Active room missing'; end if;
    perform public.appointment_action('ready',jsonb_build_object('appointment_id',room));
  end loop;
  perform set_config('request.jwt.claim.sub',m::text,true);
  perform public.appointment_action('finalize',jsonb_build_object('appointment_id',room,'notes','Shared note','rating',4));
  foreach actor in array array[m,student] loop
    perform set_config('request.jwt.claim.sub',actor::text,true);
    select x into strict row_data from jsonb_array_elements(public.appointment_feed()) x where x->>'id'=room::text;
    if not row_data @> '{"section":"history","status":"completed","notes":"Shared note"}'
       or row_data ? 'rating' then raise exception 'History or privacy failed'; end if;
  end loop;
end $verify$;
rollback;
select 'Role-scoped feed verification passed' as result;

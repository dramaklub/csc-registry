begin;
do $test$
declare
  mentor uuid := gen_random_uuid(); student uuid := gen_random_uuid();
  stranger uuid := gen_random_uuid(); room uuid; star boolean; h jsonb;
begin
  insert into private.mentor_approvals(email) values(mentor::text||'@example.invalid');
  insert into auth.users(id,email) select id,id::text||'@example.invalid' from unnest(array[mentor,student,stranger]) id;
  set local role authenticated;
  perform set_config('request.jwt.claim.sub',mentor::text,true);
  perform public.complete_onboarding('mentor');
  perform set_config('request.jwt.claim.sub',stranger::text,true);
  perform public.complete_onboarding('mentee');
  perform set_config('request.jwt.claim.sub',student::text,true);
  perform public.complete_onboarding('mentee');
  foreach star in array array[true,false] loop
    perform set_config('request.jwt.claim.sub',student::text,true);
    room := public.appointment_action('create',jsonb_build_object('topic','Other','custom_topic','History test','is_star',star));
    perform set_config('request.jwt.claim.sub',mentor::text,true);
    perform public.appointment_action('claim',jsonb_build_object('appointment_id',room));
    perform public.appointment_action('ready',jsonb_build_object('appointment_id',room));
    perform set_config('request.jwt.claim.sub',student::text,true);
    perform public.appointment_action('ready',jsonb_build_object('appointment_id',room));
    if public.session_history_detail(room) is not null then raise exception 'Unfinished room has history'; end if;
    perform set_config('request.jwt.claim.sub',mentor::text,true);
    if not star then
      begin
        perform public.appointment_action('finalize',jsonb_build_object('appointment_id',room,'notes','Shared','rating',4,'remedial_score','8/10'));
        raise exception 'Non-STAR score accepted';
      exception when raise_exception then
        if sqlerrm <> 'Remedial score requires STAR session' then raise; end if;
      end;
    end if;
    perform public.appointment_action('finalize',jsonb_build_object('appointment_id',room,'notes','Shared','rating',4,
      'remedial_score',case when star then '8/10' end));
    h := public.session_history_detail(room);
    if not coalesce(h @> jsonb_build_object('shared_notes','Shared','is_star',star,'own_rating',4,'can_leave_feedback',false,
      'remedial_score',case when star then '8/10' end),false) then raise exception 'Incorrect mentor history'; end if;
    perform set_config('request.jwt.claim.sub',student::text,true);
    if not coalesce(public.session_history_detail(room) @> '{"feedback_submitted":false,"can_leave_feedback":true,"own_rating":null,"is_star":null}',false)
      then raise exception 'Incorrect pre-feedback state'; end if;
    perform public.appointment_action('feedback',jsonb_build_object('appointment_id',room,'rating',5));
    if not coalesce(public.session_history_detail(room) @> '{"shared_notes":"Shared","feedback_submitted":true,"feedback_notes":null,"can_leave_feedback":false,"own_rating":5}',false)
      then raise exception 'Rating-only feedback missed'; end if;
    perform set_config('request.jwt.claim.sub',mentor::text,true);
    if not coalesce(public.session_history_detail(room) @> '{"feedback_submitted":true,"own_rating":4}',false)
      then raise exception 'Received rating leaked'; end if;
    perform set_config('request.jwt.claim.sub',stranger::text,true);
    if public.session_history_detail(room) is not null then raise exception 'Unrelated account saw history'; end if;
  end loop;
end $test$;
rollback;
select 'Session completion and history checks passed' as result;

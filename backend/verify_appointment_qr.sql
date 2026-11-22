begin;
do $test$
declare
  mentor uuid := gen_random_uuid();
  mentee uuid := gen_random_uuid();
  outsider uuid := gen_random_uuid();
  room uuid;
  other_room uuid;
  code uuid;
  old_code uuid;
  mentor_email text := mentor::text || '@example.invalid';
begin
  insert into private.mentor_approvals(email) values (mentor_email);
  insert into auth.users(id,email) values (mentor,mentor_email),
    (mentee,mentee::text || '@example.invalid'),(outsider,outsider::text || '@example.invalid');
  set local role authenticated;
  perform set_config('request.jwt.claim.sub',mentor::text,true);
  perform public.complete_onboarding('mentor');
  perform set_config('request.jwt.claim.sub',mentee::text,true);
  perform public.complete_onboarding('mentee');
  room := public.appointment_action('create','{"topic":"Other","custom_topic":"QR test"}');
  other_room := public.appointment_action('create','{"topic":"Other","custom_topic":"Second room"}');
  perform set_config('request.jwt.claim.sub',mentor::text,true);
  perform public.appointment_action('claim',jsonb_build_object('appointment_id',room));
  perform public.appointment_action('claim',jsonb_build_object('appointment_id',other_room));
  code := (public.issue_appointment_qr(room)->>'token')::uuid;
  if code is distinct from (public.issue_appointment_qr(room)->>'token')::uuid then raise exception 'Issue retry changed code'; end if;
  perform set_config('request.jwt.claim.sub',outsider::text,true);
  begin
    perform public.scan_appointment_qr(room,code);
    raise exception 'Outsider accepted';
  exception when raise_exception then
    if sqlerrm <> 'Code is invalid or expired for this session' then raise; end if;
  end;
  perform set_config('request.jwt.claim.sub',mentee::text,true);
  begin
    perform public.issue_appointment_qr(room);
    raise exception 'Mentee could issue code';
  exception when raise_exception then
    if sqlerrm <> 'Only the primary mentor of an accepted session can show its code' then raise; end if;
  end;
  begin
    perform public.scan_appointment_qr(other_room,code);
    raise exception 'Wrong room accepted';
  exception when raise_exception then
    if sqlerrm <> 'Code is invalid or expired for this session' then raise; end if;
  end;
  reset role;
  update private.appointment_qr set expires_at = now() - interval '1 second' where appointment_id = room;
  set local role authenticated;
  begin
    perform public.scan_appointment_qr(room,code);
    raise exception 'Expired code accepted';
  exception when raise_exception then
    if sqlerrm <> 'Code is invalid or expired for this session' then raise; end if;
  end;
  old_code := code;
  perform set_config('request.jwt.claim.sub',mentor::text,true);
  code := (public.issue_appointment_qr(room)->>'token')::uuid;
  if code is not distinct from old_code then raise exception 'Expired code not rotated'; end if;
  perform set_config('request.jwt.claim.sub',mentee::text,true);
  if public.scan_appointment_qr(room,code) is distinct from 'accepted' then raise exception 'Premature start'; end if;
  if public.scan_appointment_qr(room,code) is distinct from 'accepted' then raise exception 'Waiting retry failed'; end if;
  perform set_config('request.jwt.claim.sub',mentor::text,true);
  perform public.appointment_action('ready',jsonb_build_object('appointment_id',room));
  perform set_config('request.jwt.claim.sub',mentee::text,true);
  if public.scan_appointment_qr(room,code) is distinct from 'in_progress' then raise exception 'Active retry failed'; end if;
  perform set_config('request.jwt.claim.sub',mentor::text,true);
  code := (public.issue_appointment_qr(other_room)->>'token')::uuid;
  perform public.appointment_action('ready',jsonb_build_object('appointment_id',other_room));
  perform set_config('request.jwt.claim.sub',mentee::text,true);
  if public.scan_appointment_qr(other_room,code) is distinct from 'in_progress' then raise exception 'Mentor-first start failed'; end if;
end $test$;
rollback;
select 'QR verification passed; fixtures rolled back' as result;

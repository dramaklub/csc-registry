begin;
insert into private.mentor_approvals(email) values('clinic-test-mentor@example.invalid');
insert into auth.users(id,email,raw_user_meta_data) values
 ('00000000-0000-4000-8000-000000000101','clinic-test-mentee@example.invalid','{"role":"mentee","first_name":"Test"}'),
 ('00000000-0000-4000-8000-000000000102','clinic-test-mentor@example.invalid','{"role":"mentor","first_name":"Test"}'),
 ('00000000-0000-4000-8000-000000000103','clinic-test-outsider@example.invalid','{"role":"mentee"}');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000101',true);
do $$ begin
 if exists(select 1 from public.users where id=auth.uid() and role is not null) then raise exception 'Signup assigned a role'; end if;
 begin
   perform public.complete_onboarding('mentor');
   raise exception 'Unapproved mentor accepted';
 exception when raise_exception then
   if sqlerrm not like 'Mentor access needs clinic approval%' then raise; end if;
 end;
end $$;
select public.complete_onboarding('mentee');
do $$ begin
 begin
   perform public.complete_onboarding('mentee');
   raise exception 'Second role assignment accepted';
 exception when raise_exception then
   if sqlerrm <> 'Your role has already been set' then raise; end if;
 end;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000102',true);
select public.complete_onboarding('mentor');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000103',true);
select public.complete_onboarding('mentee');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000101',true);
select set_config('clinic.test_id', public.appointment_action('create','{"topic":"Other","custom_topic":"Git branching","is_star":true}')::text,true);
do $$ begin
 if (select count(*) from public.appointment_flags)>0 then raise exception 'Mentee can see STAR'; end if;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000103',true);
do $$ begin
 if exists(select 1 from public.appointments where id=current_setting('clinic.test_id')::uuid) then raise exception 'Unrelated mentee can read request'; end if;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000102',true);
select public.appointment_action('claim',jsonb_build_object('appointment_id',current_setting('clinic.test_id')));
select public.appointment_action('ready',jsonb_build_object('appointment_id',current_setting('clinic.test_id')));
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000101',true);
select public.appointment_action('ready',jsonb_build_object('appointment_id',current_setting('clinic.test_id')));
do $$ begin
 if not exists(select 1 from public.appointments where id=current_setting('clinic.test_id')::uuid and status='in_progress') then raise exception 'Handshake failed'; end if;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000102',true);
select public.appointment_action('finalize',jsonb_build_object('appointment_id',current_setting('clinic.test_id'),'notes','Session notes','rating',4,'remedial_score','8/10'));
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000101',true);
do $$ begin
 if exists(select 1 from public.session_ratings where appointment_id=current_setting('clinic.test_id')::uuid) then raise exception 'Received rating leaked'; end if;
 if not exists(select 1 from public.session_logs where appointment_id=current_setting('clinic.test_id')::uuid) then raise exception 'Shared notes missing'; end if;
end $$;
select public.appointment_action('feedback',jsonb_build_object('appointment_id',current_setting('clinic.test_id'),'rating',5));
do $$ begin
 if (select count(*) from public.session_ratings where appointment_id=current_setting('clinic.test_id')::uuid)<>1 then raise exception 'Own rating missing'; end if;
end $$;
rollback;
select 'Lifecycle, STAR privacy, outsider access, rating privacy: passed; test data rolled back' as result;

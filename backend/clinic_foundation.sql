create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated;
create table private.mentor_approvals(email text primary key check(email=lower(email)), approved_at timestamptz not null default now());
alter table private.mentor_approvals enable row level security;
create table public.users(
 id uuid primary key references auth.users on delete cascade,
 role text check(role in ('mentee','mentor')),
 first_name text not null default '',last_name text not null default '',
 course text,year_level integer check(year_level between 1 and 8),bio text,
 specialties text[] not null default '{}'
);
create table public.user_private_details(
 user_id uuid primary key references public.users on delete cascade,student_id text,contact_number text
);
create table public.topics(name text primary key);
insert into public.topics values ('Programming fundamentals'),('Database normalization'),('Web development'),('Intro to networking'),('Other');
create table public.appointments(
 id uuid primary key default gen_random_uuid(),mentee_id uuid not null references public.users,
 target_mentor_id uuid references public.users,topic text not null references public.topics,
 custom_topic text,course_code text,professor_name text,
 status text not null default 'pending' check(status in ('pending','accepted','in_progress','completed','cancelled')),
 scheduled_at timestamptz,mentee_ready boolean not null default false,mentor_ready boolean not null default false,
 created_at timestamptz not null default now(),
 check((topic='Other' and nullif(trim(custom_topic),'') is not null) or (topic<>'Other' and custom_topic is null))
);
create table public.appointment_flags(
 appointment_id uuid primary key references public.appointments on delete cascade,is_star boolean not null default false
);
create table public.participating_mentors(
 id uuid primary key default gen_random_uuid(),appointment_id uuid not null references public.appointments on delete cascade,
 mentor_id uuid not null references public.users,is_primary boolean not null default false,unique(appointment_id,mentor_id)
);
create unique index one_primary_mentor on public.participating_mentors(appointment_id) where is_primary;
create index mentors_by_user on public.participating_mentors(mentor_id);
create index appointments_by_mentee on public.appointments(mentee_id);
create index appointments_by_target on public.appointments(target_mentor_id);
create index pending_topics on public.appointments(topic,status);
create table public.session_logs(
 id uuid primary key default gen_random_uuid(),appointment_id uuid not null unique references public.appointments,
 notes text not null check(length(trim(notes))>0),remedial_score text
);
create table public.mentee_feedback(
 id uuid primary key default gen_random_uuid(),appointment_id uuid not null unique references public.appointments,notes text
);
create table public.session_ratings(
 appointment_id uuid not null references public.appointments,author_id uuid not null references public.users,
 rating integer not null check(rating between 1 and 5),primary key(appointment_id,author_id)
);
create index ratings_by_author on public.session_ratings(author_id);
CREATE OR REPLACE FUNCTION private.complete_onboarding(chosen_role text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare existing text;
begin
 if auth.uid() is null then raise exception 'Sign in required'; end if;
 if chosen_role is null or chosen_role not in ('mentee','mentor') then raise exception 'Choose Mentor or Mentee'; end if;
 select role into existing from public.users where id=auth.uid() for update;
 if not found then raise exception 'Profile missing'; end if;
 if existing is not null then raise exception 'Your role has already been set'; end if;
 if chosen_role='mentor' and not exists(select 1 from private.mentor_approvals a join auth.users u on lower(u.email)=a.email where u.id=auth.uid()) then
 raise exception 'Mentor access needs clinic approval. Your account has been created; contact the clinic and try again after approval.';
 end if;
 update public.users set role=chosen_role where id=auth.uid();
end $function$;
CREATE OR REPLACE FUNCTION private.on_signup()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
 insert into public.users(id,first_name,last_name) values(new.id,coalesce(new.raw_user_meta_data->>'first_name',''),coalesce(new.raw_user_meta_data->>'last_name',''));
 insert into public.user_private_details(user_id) values(new.id);
 return new;
end $function$;
CREATE OR REPLACE FUNCTION public.complete_onboarding(chosen_role text)
 RETURNS void
 LANGUAGE sql
 SET search_path TO ''
AS $function$ select private.complete_onboarding(chosen_role); $function$;
revoke all on function private.complete_onboarding(text),public.complete_onboarding(text) from public, anon;
grant execute on function private.complete_onboarding(text),public.complete_onboarding(text) to authenticated;
revoke all on function private.on_signup() from public;
create trigger clinic_signup after insert on auth.users for each row execute function private.on_signup();
create function private.is_mentor() returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and exists(select 1 from public.users where id=auth.uid() and role='mentor');
$$;
create function private.participates(aid uuid) returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and (exists(select 1 from public.appointments where id=aid and mentee_id=auth.uid()) or exists(select 1 from public.participating_mentors where appointment_id=aid and mentor_id=auth.uid()));
$$;
create function private.can_view(aid uuid) returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and (private.participates(aid) or exists(
 select 1 from public.appointments a join public.users u on u.id=auth.uid() and u.role='mentor'
 where a.id=aid and
 ((a.status='pending' and (a.target_mentor_id is null or a.target_mentor_id=u.id) and (a.topic='Other' or a.topic=any(u.specialties)))
 or a.status in ('accepted','in_progress'))));
$$;
revoke all on function private.is_mentor(),private.participates(uuid),private.can_view(uuid) from public;
grant execute on function private.is_mentor(),private.participates(uuid),private.can_view(uuid) to authenticated;
alter table public.users enable row level security;
alter table public.user_private_details enable row level security;
alter table public.topics enable row level security;
alter table public.appointments enable row level security;
alter table public.appointment_flags enable row level security;
alter table public.participating_mentors enable row level security;
alter table public.session_logs enable row level security;
alter table public.mentee_feedback enable row level security;
alter table public.session_ratings enable row level security;
revoke all on public.users,public.user_private_details,public.topics,public.appointments,public.appointment_flags,public.participating_mentors,public.session_logs,public.mentee_feedback,public.session_ratings from anon,authenticated;
grant select on public.users,public.user_private_details,public.topics,public.appointments,public.appointment_flags,public.participating_mentors,public.session_logs,public.mentee_feedback,public.session_ratings to authenticated;
grant update(first_name,last_name,course,year_level,bio,specialties) on public.users to authenticated;
grant update(student_id,contact_number) on public.user_private_details to authenticated;
create policy profiles_read on public.users for select to authenticated using(true);
create policy profile_edit on public.users for update to authenticated using(id=(select auth.uid())) with check(id=(select auth.uid()));
create policy personal_read on public.user_private_details for select to authenticated using(user_id=(select auth.uid()));
create policy personal_edit on public.user_private_details for update to authenticated using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
create policy topics_read on public.topics for select to authenticated using(true);
create policy appointments_read on public.appointments for select to authenticated using(private.can_view(id));
create policy flags_read on public.appointment_flags for select to authenticated using((select private.is_mentor()) and private.can_view(appointment_id));
create policy participants_read on public.participating_mentors for select to authenticated using(private.can_view(appointment_id));
create policy logs_read on public.session_logs for select to authenticated using(private.participates(appointment_id));
create policy feedback_read on public.mentee_feedback for select to authenticated using(private.participates(appointment_id));
create policy ratings_read on public.session_ratings for select to authenticated using(author_id=(select auth.uid()));
-- Only this validated transaction function writes lifecycle data. The public RPC wrapper is an invoker.
create function private.appointment_action(action text, payload jsonb) returns uuid language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); aid uuid; a public.appointments; target uuid; primary_mentor boolean; myrole text;
begin
 if uid is null then raise exception 'Sign in required'; end if;
 select role into myrole from public.users where id=uid;
 if myrole is null then raise exception 'Profile missing'; end if;
 if action='create' then
  if myrole<>'mentee' then raise exception 'Only mentees create requests'; end if;
  target:=nullif(payload->>'target_mentor_id','')::uuid;
  if target is not null and not exists(select 1 from public.users where id=target and role='mentor' and (payload->>'topic'='Other' or payload->>'topic'=any(specialties))) then raise exception 'Mentor is not eligible for topic'; end if;
  insert into public.appointments(mentee_id,target_mentor_id,topic,custom_topic,scheduled_at,course_code,professor_name)
  values(uid,target,payload->>'topic',case when payload->>'topic'='Other' then trim(payload->>'custom_topic') end,
  nullif(payload->>'scheduled_at','')::timestamptz,nullif(trim(payload->>'course_code'),''),nullif(trim(payload->>'professor_name'),''))
  returning id into aid;
  insert into public.appointment_flags values(aid,coalesce((payload->>'is_star')::boolean,false));
  return aid;
 end if;
 aid:=(payload->>'appointment_id')::uuid;
 select * into a from public.appointments where id=aid for update;
 if not found then raise exception 'Request not found'; end if;
 select exists(select 1 from public.participating_mentors where appointment_id=aid and mentor_id=uid and is_primary) into primary_mentor;
 if action='claim' then
  if myrole<>'mentor' or a.status<>'pending' or (a.target_mentor_id is not null and a.target_mentor_id<>uid) or not exists(select 1 from public.users where id=uid and (a.topic='Other' or a.topic=any(specialties))) then raise exception 'Request unavailable or not eligible'; end if;
  insert into public.participating_mentors(appointment_id,mentor_id,is_primary) values(aid,uid,true);
  update public.appointments set status='accepted' where id=aid;
 elsif action='join' then
  if myrole<>'mentor' or a.status not in ('accepted','in_progress') then raise exception 'Cannot join this room'; end if;
  insert into public.participating_mentors(appointment_id,mentor_id) values(aid,uid) on conflict(appointment_id,mentor_id) do nothing;
 elsif action='cancel' then
  if a.mentee_id<>uid or a.status<>'pending' then raise exception 'Only pending own requests can be cancelled'; end if;
  update public.appointments set status='cancelled' where id=aid;
 elsif action='retarget' then
  if a.mentee_id<>uid or a.status<>'pending' then raise exception 'Only pending own requests can be changed'; end if;
  target:=nullif(payload->>'target_mentor_id','')::uuid;
  if target is not null and not exists(select 1 from public.users where id=target and role='mentor' and (a.topic='Other' or a.topic=any(specialties))) then raise exception 'Mentor is not eligible'; end if;
  update public.appointments set target_mentor_id=target where id=aid;
 elsif action='ready' then
  if a.status<>'accepted' or not(a.mentee_id=uid or primary_mentor) then raise exception 'Cannot mark ready'; end if;
  update public.appointments set mentee_ready=mentee_ready or mentee_id=uid,mentor_ready=mentor_ready or primary_mentor where id=aid;
  update public.appointments set status='in_progress' where id=aid and mentee_ready and mentor_ready;
 elsif action='finalize' then
  if not primary_mentor or a.status<>'in_progress' then raise exception 'Only primary mentor can finalize an active session'; end if;
  if nullif(trim(payload->>'remedial_score'),'') is not null and not exists(select 1 from public.appointment_flags where appointment_id=aid and is_star) then raise exception 'Remedial score requires STAR session'; end if;
  insert into public.session_logs(appointment_id,notes,remedial_score) values(aid,trim(payload->>'notes'),nullif(trim(payload->>'remedial_score'),''));
  insert into public.session_ratings values(aid,uid,(payload->>'rating')::integer);
  update public.appointments set status='completed' where id=aid;
 elsif action='feedback' then
  if a.mentee_id<>uid or a.status<>'completed' then raise exception 'Feedback requires own completed session'; end if;
  insert into public.mentee_feedback(appointment_id,notes) values(aid,nullif(trim(payload->>'notes'),''));
  insert into public.session_ratings values(aid,uid,(payload->>'rating')::integer);
 else raise exception 'Unknown action';
 end if;
 return aid;
end $$;
revoke all on function private.appointment_action(text,jsonb) from public;
grant execute on function private.appointment_action(text,jsonb) to authenticated;
create function public.appointment_action(action text,payload jsonb) returns uuid language sql security invoker set search_path='' as $$
 select private.appointment_action(action,payload);
$$;
revoke all on function public.appointment_action(text,jsonb) from public,anon;
grant execute on function public.appointment_action(text,jsonb) to authenticated;
alter publication supabase_realtime add table public.appointments,public.participating_mentors;

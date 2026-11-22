-- QR contents are the opaque token. The scanner supplies its current room ID separately.
create table private.appointment_qr (
  appointment_id uuid primary key references public.appointments(id) on delete cascade,
  token uuid not null unique,
  expires_at timestamptz not null
);
alter table private.appointment_qr enable row level security;
revoke all on private.appointment_qr from public, anon, authenticated;

create function private.issue_appointment_qr(room_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  code private.appointment_qr;
begin
  perform 1 from public.appointments a
  where a.id = room_id and a.status = 'accepted'
    and exists (select 1 from public.participating_mentors p
                where p.appointment_id = a.id and p.mentor_id = auth.uid() and p.is_primary)
  for update;
  if not found then raise exception 'Only the primary mentor of an accepted session can show its code'; end if;

  select * into code from private.appointment_qr where appointment_id = room_id;
  if not found or code.expires_at <= clock_timestamp() then
    insert into private.appointment_qr values (room_id, gen_random_uuid(), clock_timestamp() + interval '5 minutes')
    on conflict (appointment_id) do update set token = excluded.token, expires_at = excluded.expires_at
    returning * into code;
  end if;
  return jsonb_build_object('token', code.token, 'expires_at', code.expires_at);
end $$;

create function private.scan_appointment_qr(room_id uuid, qr_token uuid) returns text
language plpgsql security definer set search_path = '' as $$
declare
  room public.appointments;
begin
  select * into room from public.appointments
  where id = room_id and mentee_id = auth.uid() and status in ('accepted','in_progress')
  for update;
  if not found or not exists (
    select 1 from private.appointment_qr
    where appointment_id = room_id and token = qr_token and expires_at > clock_timestamp()
  ) then raise exception 'Code is invalid or expired for this session'; end if;

  if room.status = 'accepted' and not room.mentee_ready then
    perform private.appointment_action('ready', jsonb_build_object('appointment_id', room_id));
    select * into room from public.appointments where id = room_id;
  end if;
  return room.status;
end $$;

create function public.issue_appointment_qr(room_id uuid) returns jsonb
language sql security invoker set search_path = '' as $$ select private.issue_appointment_qr(room_id) $$;
create function public.scan_appointment_qr(room_id uuid, qr_token uuid) returns text
language sql security invoker set search_path = '' as $$ select private.scan_appointment_qr(room_id, qr_token) $$;

revoke all on function public.issue_appointment_qr(uuid), private.issue_appointment_qr(uuid),
  public.scan_appointment_qr(uuid,uuid), private.scan_appointment_qr(uuid,uuid) from public, anon;
grant execute on function public.issue_appointment_qr(uuid), private.issue_appointment_qr(uuid),
  public.scan_appointment_qr(uuid,uuid), private.scan_appointment_qr(uuid,uuid) to authenticated;

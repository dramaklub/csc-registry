# Backend and authentication foundation

For a fresh Supabase project, apply `clinic_foundation.sql`, `appointment_qr.sql`,
`appointment_feed.sql`, `request_reads.sql`, and `session_history.sql` in order.
Then run the five `verify_*.sql` transaction scripts.

Project: CCE Skills Clinic
Project reference: dpbfgyhsshoosaolniqb
Dashboard: https://supabase.com/dashboard/project/dpbfgyhsshoosaolniqb

## Implemented
- Email/password registration and login; session persistence and sign-out.
- Signup creates a profile with a null role. After sign-in, `complete_onboarding`
  assigns the user's permanent role once. Mentor selection requires clinic approval.
- Role-aware home placeholder (appointment screens are not implemented yet).
- Database lifecycle RPC: create, claim, join, retarget, cancel, ready, finalize, feedback.
- Row locking serializes concurrent claims and Ready changes.
- Realtime enabled for appointments and participating mentors.
- Received ratings are inaccessible through the client API.
- STAR flags are kept in a mentor-readable table; mentees can request STAR during creation.
- Private student ID/contact fields are owner-only.
- The topic catalog starts with the four topics shown in the prototype plus Other.
- The primary mentor can issue a five-minute QR token for an accepted appointment.
  Encode the returned token as the QR contents. The mentee submits the scanned token
  alongside the appointment ID from their open session room. A valid scan marks the
  mentee ready and returns the current status. Manual Ready remains available.
  See `appointment_qr.sql` and its rollback test `verify_appointment_qr.sql`.

## Approve a mentor before role selection
Use the Supabase SQL Editor as the project owner, replacing the example email:

```sql
insert into private.mentor_approvals(email)
values (lower('approved-mentor@example.edu'))
on conflict (email) do nothing;
```

The signed-in person can then choose Mentor, including after an earlier approval denial.
An existing Mentee account cannot switch roles through the app.
Mentor specialties can currently be edited by the project owner in public.users.
The profile editing screen will expose the permitted fields in a later step.

## Run
From theregistry:
```
flutter pub get
flutter analyze
flutter test
flutter run
```
Only a publishable client key is included in main.dart. RLS and RPC checks enforce authorization.
Email confirmation remains enabled according to the project's Auth settings. Complete confirmation
then return to login. Actual email delivery needs checking with a real approved account.
Android recovery requires the exact redirect URL `cce-skills-clinic://auth/recovery`
in Authentication → URL Configuration → Redirect URLs. Request a fresh reset from
the installed app and open the email link on the same phone for the PKCE exchange.

## API
Call appointment_action with action and payload:
- create: topic, optional custom_topic (required for Other), target_mentor_id, scheduled_at,
  course_code, professor_name, is_star.
- claim / join / ready / cancel: appointment_id.
- retarget: appointment_id, target_mentor_id (null reopens it).
- finalize: appointment_id, notes (required), rating (1–5), optional remedial_score for STAR.
- feedback: appointment_id, rating (1–5), optional notes. Skipping feedback requires no write.

All lifecycle table writes are denied directly to clients; use the RPC.
Shared session notes live in session_logs, feedback notes in mentee_feedback,
and author-only ratings in session_ratings. This deliberately improves the original
plan, which stored received ratings alongside shared notes.
Dates use timestamptz; send UTC from Flutter and display local time.

## Verification
verify_foundation.sql exercises authenticated actors with temporary users, then rolls back:
create → claim → both Ready → in_progress → finalize → feedback, plus STAR visibility,
unrelated-mentee access and rating privacy.
Direct client status updates, role edits, and anonymous appointment reads are denied.
The private approvals table intentionally has RLS without client policies (deny all).

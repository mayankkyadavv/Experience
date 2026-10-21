-- Captures (ADR-012): a photo or video the user took in the app. Media stays on the device;
-- the server keeps only that it happened and which Experience it belongs to. No coordinates.
create type capture_kind as enum ('photo', 'video');

create table captures (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  experience_id uuid references experiences (id) on delete set null,
  kind capture_kind not null,
  taken_at timestamptz not null,
  duration_seconds real check (duration_seconds >= 0),
  device_media_id text,                    -- the file name on the device, so the app can find it again
  created_at timestamptz not null default now()
);
create index captures_user_taken on captures (user_id, taken_at desc);
create index captures_experience on captures (experience_id);

alter table captures enable row level security;
create policy captures_own on captures for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

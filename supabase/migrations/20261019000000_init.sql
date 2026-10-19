-- Experience: initial schema (ADR-006 amended by ADR-009, city-first).
-- Catalog tables are readable by signed-in users and written only by the service role.
-- Every user table is owner-only under RLS.

-- Where a displayed value came from (R8). `curated` = editorial catalog data (ADR-009).
create type provenance as enum ('source', 'lookup', 'estimated', 'user', 'curated');
create type location_requirement as enum ('exact', 'flexible', 'none');
create type city_status as enum ('coming', 'beta', 'live');
create type experience_visibility as enum ('catalog', 'private');
create type experience_status as enum ('draft', 'published', 'archived');
create type place_role as enum ('primary', 'candidate');
create type occasion as enum ('solo', 'date', 'friends', 'group', 'family');
-- Replaces the earlier 13-value list: adds classes, sports, comedy, music, games, wellness (MVP.md open decision 6).
create type experience_category as enum (
  'food', 'cafe', 'dessert', 'bar', 'nightlife', 'music', 'comedy', 'arts_culture', 'attraction',
  'outdoors', 'sports', 'active', 'class', 'games', 'shopping', 'market', 'event', 'wellness', 'lodging', 'other'
);
create type job_status as enum ('queued', 'running', 'done', 'needs_review');

-- Cities -------------------------------------------------------------------

create table cities (
  id text primary key,                       -- slug, e.g. 'philadelphia'
  name text not null,
  region text,
  country text not null,
  timezone text not null,                    -- IANA, e.g. 'America/New_York'
  status city_status not null default 'coming',
  center_lat double precision not null,
  center_lng double precision not null,
  created_at timestamptz not null default now()
);

-- Places: shared provider cache (ADR-003). place_id-style ids are kept; other fields expire per provider terms.

create table places (
  id uuid primary key default gen_random_uuid(),
  city_id text references cities (id),
  provider text not null check (provider in ('apple', 'osm', 'manual')),
  provider_place_id text,
  name text not null,
  address text,
  neighborhood text,
  lat double precision,
  lng double precision,
  cached_at timestamptz not null default now(),
  expires_at timestamptz,
  unique (provider, provider_place_id)
);

-- Experiences: the root object. Catalog entries are shared; shared posts can create private ones.

create table experiences (
  id uuid primary key default gen_random_uuid(),
  city_id text references cities (id),       -- null when outside every supported city
  visibility experience_visibility not null default 'catalog',
  status experience_status not null default 'draft',
  created_by uuid references auth.users (id) on delete cascade,
  title text not null,
  intent text,
  description text,
  category experience_category not null,
  tags text[] not null default '{}',
  good_for occasion[] not null default '{}',
  location_requirement location_requirement not null default 'exact',
  price_min_cents integer check (price_min_cents >= 0),
  price_max_cents integer check (price_max_cents >= price_min_cents),
  duration_min_minutes integer check (duration_min_minutes > 0),
  duration_max_minutes integer check (duration_max_minutes >= duration_min_minutes),
  group_min smallint check (group_min >= 1),
  group_max smallint check (group_max >= group_min),
  -- Weekly hours: [{"day":0-6 (0=Sunday), "open":"HH:MM", "close":"HH:MM"}]; close <= open means past midnight.
  -- Empty array = no fixed hours (always possible, e.g. a park walk).
  hours jsonb not null default '[]',
  -- Dated availability for events and seasonal things: [{"start":"YYYY-MM-DD","end":"YYYY-MM-DD"}]. Empty = year-round.
  dates jsonb not null default '[]',
  image_url text,
  -- Per-field provenance: {"title":"curated","price_min_cents":"estimated",...}. Missing = curated for catalog rows.
  provenance jsonb not null default '{}',
  source_id uuid,                            -- set for Experiences created from a shared post
  review_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((visibility = 'private') = (created_by is not null))
);
create index experiences_city_published on experiences (city_id) where status = 'published' and visibility = 'catalog';

create table experience_places (
  experience_id uuid not null references experiences (id) on delete cascade,
  place_id uuid not null references places (id),
  role place_role not null default 'primary',
  confidence real,
  primary key (experience_id, place_id)
);

-- Profiles and taste -------------------------------------------------------

create table profiles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  city_id text references cities (id),
  display_name text,
  -- {"likes":["comedy","outdoors",...], "budget":"50", "usually_with":"partner"}
  onboarding jsonb not null default '{}',
  onboarded_at timestamptz,
  created_at timestamptz not null default now()
);

-- One row per user per Experience; timestamps record each signal (MVP feedback list).
create table user_experiences (
  user_id uuid not null references auth.users (id) on delete cascade,
  experience_id uuid not null references experiences (id) on delete cascade,
  saved_at timestamptz,
  interested_at timestamptz,
  not_interested_at timestamptz,
  done_at timestamptz,
  rating smallint check (rating between 1 and 3),   -- 1 not for me · 2 good · 3 loved (scale is an open founder decision)
  from_recommendation uuid,
  updated_at timestamptz not null default now(),
  primary key (user_id, experience_id)
);

create table recommendation_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  city_id text not null references cities (id),
  constraints jsonb not null,
  results jsonb not null,                    -- [{"experience_id", "score", "reasons":[...]}]
  created_at timestamptz not null default now()
);

-- Capture (ADR-004/005/007) -----------------------------------------------

create table sources (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  save_id uuid not null,
  url text not null,
  platform text not null check (platform in ('tiktok', 'instagram', 'youtube')),
  creator text,
  user_hint jsonb,
  saved_at timestamptz not null default now(),
  unique (user_id, save_id)
);
alter table experiences add constraint experiences_source_fk foreign key (source_id) references sources (id) on delete set null;

create table identification_candidates (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  source_id uuid not null references sources (id) on delete cascade,
  candidates jsonb not null,
  model text,
  created_at timestamptz not null default now()
);

create table jobs (
  id uuid primary key default gen_random_uuid(),
  source_id uuid not null unique references sources (id) on delete cascade,
  status job_status not null default 'queued',
  attempts smallint not null default 0,
  last_error text,
  run_after timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table events (
  id bigint generated always as identity primary key,
  user_id uuid references auth.users (id) on delete cascade,
  name text not null,
  props jsonb not null default '{}',
  at timestamptz not null default now()
);
create index events_user_at on events (user_id, at);

-- RLS -------------------------------------------------------------------------

alter table cities enable row level security;
alter table places enable row level security;
alter table experiences enable row level security;
alter table experience_places enable row level security;
alter table profiles enable row level security;
alter table user_experiences enable row level security;
alter table recommendation_requests enable row level security;
alter table sources enable row level security;
alter table identification_candidates enable row level security;
alter table jobs enable row level security;
alter table events enable row level security;

create policy cities_read on cities for select to authenticated using (true);
create policy places_read on places for select to authenticated using (true);
create policy experiences_read on experiences for select to authenticated
  using ((visibility = 'catalog' and status = 'published') or created_by = auth.uid());
create policy experience_places_read on experience_places for select to authenticated
  using (exists (select 1 from experiences e where e.id = experience_id
                 and ((e.visibility = 'catalog' and e.status = 'published') or e.created_by = auth.uid())));

create policy profiles_own on profiles for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy user_experiences_own on user_experiences for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy recommendation_requests_own on recommendation_requests for select to authenticated using (user_id = auth.uid());
create policy sources_own on sources for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy identification_candidates_own on identification_candidates for select to authenticated using (user_id = auth.uid());
create policy events_insert_own on events for insert to authenticated with check (user_id = auth.uid());
-- jobs: service role only (no policies).

-- Seed cities -----------------------------------------------------------------

insert into cities (id, name, region, country, timezone, status, center_lat, center_lng) values
  ('philadelphia', 'Philadelphia', 'PA', 'US', 'America/New_York', 'beta', 39.9524, -75.1636),
  ('new-york', 'New York', 'NY', 'US', 'America/New_York', 'coming', 40.7580, -73.9855);

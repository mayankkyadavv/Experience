-- Data model v2 (ADR-011): links, dated occurrences, recommendation items, social graph, profile handles.
-- Additive only: every v1 table and column keeps its meaning.

-- Experiences: an explicit kind and a sub-category for finer filtering.
create type experience_kind as enum ('place', 'activity', 'event', 'route');
alter table experiences
  add column kind experience_kind not null default 'place',
  add column subcategory text,                 -- free text inside a category, e.g. 'jazz', 'pottery', 'speakeasy'
  add column slug text unique;                 -- catalog/<city>/<slug>.json for catalog rows

-- Links: every URL attached to an Experience (official site, tickets, menu, socials, research sources).
create type link_kind as enum ('website', 'tickets', 'booking', 'menu', 'instagram', 'tiktok', 'youtube', 'source', 'other');
create table experience_links (
  id uuid primary key default gen_random_uuid(),
  experience_id uuid not null references experiences (id) on delete cascade,
  kind link_kind not null,
  url text not null,
  title text,
  provenance provenance not null default 'estimated',
  created_at timestamptz not null default now(),
  unique (experience_id, url)
);
create index experience_links_experience on experience_links (experience_id);

-- Occurrences: concrete dates for events (a concert on Nov 7, a festival weekend). Recurring places use `hours`.
create table experience_occurrences (
  id uuid primary key default gen_random_uuid(),
  experience_id uuid not null references experiences (id) on delete cascade,
  starts_at timestamptz not null,
  ends_at timestamptz,
  price_min_cents integer check (price_min_cents >= 0),
  price_max_cents integer check (price_max_cents >= price_min_cents),
  ticket_url text,
  status text not null default 'scheduled' check (status in ('scheduled', 'sold_out', 'cancelled')),
  provenance provenance not null default 'estimated',
  unique (experience_id, starts_at)
);
create index experience_occurrences_upcoming on experience_occurrences (starts_at);

-- Recommendation items: one row per pick shown, so feedback can be joined to what was recommended and where.
create table recommendation_items (
  request_id uuid not null references recommendation_requests (id) on delete cascade,
  experience_id uuid not null references experiences (id) on delete cascade,
  position smallint not null,
  score real not null,
  reasons text[] not null default '{}',
  primary key (request_id, experience_id)
);
alter table user_experiences
  add constraint user_experiences_from_recommendation_fkey
  foreign key (from_recommendation) references recommendation_requests (id) on delete set null;

-- Profiles: a public handle for friends (vision; no UI in the MVP).
alter table profiles
  add column username text unique check (username ~ '^[a-z0-9_]{3,24}$'),
  add column avatar_url text;

-- Social graph (vision, CLAUDE.md "Not building yet"): tables exist so later features don't need a reshape.
create type friendship_status as enum ('pending', 'accepted', 'blocked');
create table friendships (
  requester_id uuid not null references auth.users (id) on delete cascade,
  addressee_id uuid not null references auth.users (id) on delete cascade,
  status friendship_status not null default 'pending',
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  primary key (requester_id, addressee_id),
  check (requester_id <> addressee_id)
);

create type group_role as enum ('owner', 'member');
create table groups (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  city_id text references cities (id),
  created_by uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);
create table group_members (
  group_id uuid not null references groups (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  role group_role not null default 'member',
  joined_at timestamptz not null default now(),
  primary key (group_id, user_id)
);
-- A recommendation can be asked for a group (who = group) later.
alter table recommendation_requests add column group_id uuid references groups (id) on delete set null;

-- Events: index for funnel queries by name.
create index events_name_at on events (name, at);

-- RLS ------------------------------------------------------------------------

alter table experience_links enable row level security;
alter table experience_occurrences enable row level security;
alter table recommendation_items enable row level security;
alter table friendships enable row level security;
alter table groups enable row level security;
alter table group_members enable row level security;

-- Links and occurrences follow their Experience's visibility.
create policy experience_links_read on experience_links for select to authenticated
  using (exists (select 1 from experiences e where e.id = experience_id
                 and ((e.visibility = 'catalog' and e.status = 'published') or e.created_by = auth.uid())));
create policy experience_occurrences_read on experience_occurrences for select to authenticated
  using (exists (select 1 from experiences e where e.id = experience_id
                 and ((e.visibility = 'catalog' and e.status = 'published') or e.created_by = auth.uid())));

create policy recommendation_items_own on recommendation_items for select to authenticated
  using (exists (select 1 from recommendation_requests r where r.id = request_id and r.user_id = auth.uid()));

-- Either side sees the friendship; only the requester creates it; only the addressee answers it.
create policy friendships_read on friendships for select to authenticated
  using (auth.uid() in (requester_id, addressee_id));
create policy friendships_request on friendships for insert to authenticated
  with check (requester_id = auth.uid() and status = 'pending');
create policy friendships_answer on friendships for update to authenticated
  using (addressee_id = auth.uid()) with check (addressee_id = auth.uid());
create policy friendships_remove on friendships for delete to authenticated
  using (auth.uid() in (requester_id, addressee_id));

-- Membership check without recursive RLS.
create function is_group_member(g uuid) returns boolean
language sql stable security definer set search_path = public
as $$ select exists (select 1 from group_members where group_id = g and user_id = auth.uid()) $$;
revoke execute on function is_group_member(uuid) from public, anon;
grant execute on function is_group_member(uuid) to authenticated;

create policy groups_read on groups for select to authenticated using (is_group_member(id) or created_by = auth.uid());
create policy groups_create on groups for insert to authenticated with check (created_by = auth.uid());
create policy groups_owner_update on groups for update to authenticated using (created_by = auth.uid());
create policy group_members_read on group_members for select to authenticated using (is_group_member(group_id));
create policy group_members_join_own_group on group_members for insert to authenticated
  with check (exists (select 1 from groups g where g.id = group_id and g.created_by = auth.uid()));
create policy group_members_leave on group_members for delete to authenticated using (user_id = auth.uid());

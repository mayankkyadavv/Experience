-- The personal Experience (ADR-013, EXPERIENCES_PRODUCT.md §3-5, §9).
--
-- 1. The city catalog becomes reference *listings* ("Things you could do", brief §10): experiences → listings,
--    experience_places/links/occurrences → listing_*. Saving a listing creates the person's own Experience.
-- 2. `experiences` is now one person's Experience across its whole life: want → planned → (in progress) →
--    experienced, or cancelled. The same id is the saved idea, the plan and the memory.
-- 3. Collections group Experiences (a trip, a festival, a season, a person) without copying them.
-- 4. Media, reflections and participation hang off the Experience.
-- 5. One access rule, can_view(owner, visibility), decides who sees what, everywhere.
-- 6. user_experiences (one row per user per catalog row) can't hold repeat visits or keep an id from want to
--    memory, so its saves and "Did it"s move into Experiences; what's left (interested / not interested) is
--    listing_signals. record_feedback keeps its signature on top of the new model, so clients keep working.

-- 1. Listings -------------------------------------------------------------------------------------------------

alter table experiences rename to listings;
alter index experiences_city_published rename to listings_city_published;
alter table listings rename constraint experiences_source_fk to listings_source_fk;
alter policy experiences_read on listings rename to listings_read;

alter table experience_places rename to listing_places;
alter table listing_places rename column experience_id to listing_id;
alter policy experience_places_read on listing_places rename to listing_places_read;

alter table experience_links rename to listing_links;
alter table listing_links rename column experience_id to listing_id;
alter index experience_links_experience rename to listing_links_listing;
alter policy experience_links_read on listing_links rename to listing_links_read;

alter table experience_occurrences rename to listing_occurrences;
alter table listing_occurrences rename column experience_id to listing_id;
alter index experience_occurrences_upcoming rename to listing_occurrences_upcoming;
alter policy experience_occurrences_read on listing_occurrences rename to listing_occurrences_read;

alter table recommendation_items rename column experience_id to listing_id;

-- 2. Experiences ----------------------------------------------------------------------------------------------

create type experience_state as enum ('want', 'planned', 'in_progress', 'experienced', 'cancelled');
create type audience as enum ('private', 'friends', 'public');
-- How precisely we know when it happened. 'unknown' has no dates; 'season'/'range' keep a start and an end
-- ("Summer 2021" stays a range, never an invented June 1).
create type time_precision as enum ('exact', 'day', 'month', 'season', 'year', 'range', 'unknown');

create table experiences (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  save_id uuid,                                  -- the client's idempotency key: a retried save never duplicates
  state experience_state not null default 'experienced',
  is_draft boolean not null default false,
  archived_at timestamptz,
  visibility audience not null default 'private',
  title text not null check (char_length(title) between 1 and 200),
  description text check (char_length(description) <= 5000),
  -- Brief §13: a manageable starting set; several can apply.
  categories text[] not null default '{}' check (categories <@ array[
    'food', 'nightlife', 'music', 'arts_culture', 'outdoors', 'travel', 'sports', 'learning', 'everyday', 'milestones'
  ]::text[]),
  tags text[] not null default '{}',
  -- Time: autobiographical time, separate from the technical timestamps below.
  starts_at timestamptz,
  ends_at timestamptz,
  time_precision time_precision not null default 'unknown',
  timezone text,                                 -- IANA zone where it happened, kept for travel and late nights
  -- Place: optional. One place for now; ordered stops arrive with moments.
  place_name text,
  place_locality text,                           -- the broad area a visitor may see, e.g. "Fishtown, Philadelphia"
  place_lat double precision,
  place_lng double precision,
  place_ref uuid references places (id) on delete set null,
  city_id text references cities (id),
  -- Where it came from.
  listing_id uuid references listings (id) on delete set null,
  inspired_by uuid references experiences (id) on delete set null,
  recommendation_id uuid references recommendation_requests (id) on delete set null,
  completed_at timestamptz,                      -- when it was confirmed as lived; set only while experienced
  cover_media_id uuid,                           -- foreign key added below, after media_assets
  -- Per-field provenance (R8): {"title":"user","time":"estimated",...}. Missing = user.
  provenance jsonb not null default '{}',
  revision integer not null default 1,
  schema_version smallint not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (owner_id, save_id),
  check (ends_at is null or starts_at is null or ends_at >= starts_at),
  check ((time_precision = 'unknown') = (starts_at is null)),
  check ((place_lat is null) = (place_lng is null))
);
create index experiences_owner_time on experiences (owner_id, starts_at desc nulls last);
create index experiences_owner_listing on experiences (owner_id, listing_id) where listing_id is not null;

-- Keeps the bookkeeping honest: revision and updated_at on every edit; completed_at only while experienced.
create function experiences_touch() returns trigger
language plpgsql set search_path = public
as $$
begin
  if tg_op = 'UPDATE' then
    new.updated_at := now();
    new.revision := old.revision + 1;
    new.owner_id := old.owner_id;                -- ownership never changes by edit
  end if;
  if new.state = 'experienced' then
    if tg_op = 'INSERT' or old.state <> 'experienced' then
      new.completed_at := coalesce(new.completed_at, now());
    end if;
  else
    new.completed_at := null;
  end if;
  return new;
end;
$$;
create trigger experiences_touch before insert or update on experiences
  for each row execute function experiences_touch();

-- 3. Collections ------------------------------------------------------------------------------------------------

create table collections (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  save_id uuid,
  title text not null check (char_length(title) between 1 and 120),
  description text check (char_length(description) <= 2000),
  kind text not null default 'other' check (kind in ('trip', 'event', 'season', 'person', 'place', 'ritual', 'other')),
  visibility audience not null default 'private',
  cover_media_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (owner_id, save_id)
);

-- An Experience can sit in several collections; a collection never copies it.
create table collection_items (
  collection_id uuid not null references collections (id) on delete cascade,
  experience_id uuid not null references experiences (id) on delete cascade,
  position integer not null default 0,
  added_at timestamptz not null default now(),
  primary key (collection_id, experience_id)
);
create index collection_items_experience on collection_items (experience_id);

-- 4. Media, reflections, participation ----------------------------------------------------------------------

create type media_kind as enum ('photo', 'video');
-- on_device: saved on the phone, not uploaded yet · uploading · ready: original stored · failed: needs attention.
create type media_status as enum ('on_device', 'uploading', 'ready', 'failed');

create table media_assets (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  experience_id uuid not null references experiences (id) on delete cascade,
  client_id uuid not null,                       -- idempotent uploads: the phone's id for this file
  kind media_kind not null,
  position integer not null default 0,
  caption text check (char_length(caption) <= 2000),
  alt_text text check (char_length(alt_text) <= 1000),
  taken_at timestamptz,
  duration_seconds real check (duration_seconds >= 0),
  width integer,
  height integer,
  byte_size bigint,
  content_type text,
  original_path text,                            -- object in the private `media` bucket; the original, untouched
  thumb_path text,                               -- a replaceable derivative, location metadata stripped
  device_file text,                              -- the file's name on the phone while it waits to upload
  status media_status not null default 'on_device',
  created_at timestamptz not null default now(),
  unique (owner_id, client_id)
);
create index media_assets_experience on media_assets (experience_id, position);

alter table experiences add constraint experiences_cover_fk
  foreign key (cover_media_id) references media_assets (id) on delete set null;
alter table collections add constraint collections_cover_fk
  foreign key (cover_media_id) references media_assets (id) on delete set null;

-- Per-person meaning (brief §14): always the author's alone, even on a Public Experience.
create table reflections (
  id uuid primary key default gen_random_uuid(),
  experience_id uuid not null references experiences (id) on delete cascade,
  author_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  rating smallint,                               -- no default: unrated is not zero
  rating_scale smallint not null default 5 check (rating_scale in (3, 5)),  -- 3 = the beta's three tiles
  would_do_again text check (would_do_again in ('yes', 'maybe', 'no')),
  body text check (char_length(body) <= 20000),
  favorite_moment text check (char_length(favorite_moment) <= 2000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (experience_id, author_id),
  check (rating between 1 and rating_scale)
);

-- Who took part. Being listed is not attendance, and it grants no access (brief §8, §9).
create table participations (
  experience_id uuid not null references experiences (id) on delete cascade,
  person_id uuid not null references auth.users (id) on delete cascade,
  role text not null default 'participant' check (role in ('participant', 'contributor')),
  invitation text check (invitation in ('invited', 'accepted', 'declined')),
  attendance text not null default 'unconfirmed' check (attendance in ('unconfirmed', 'confirmed', 'declined')),
  display_approved boolean not null default false,
  created_at timestamptz not null default now(),
  primary key (experience_id, person_id)
);

-- 5. One access rule ------------------------------------------------------------------------------------------
-- Used by every policy below; later by media signing, search, counts and feeds. Friends = the owner's accepted
-- friends, never the union of participants' friends. A block in either direction removes friend access.

create function are_friends(a uuid, b uuid) returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (select 1 from friendships
                 where status = 'accepted'
                   and ((requester_id = a and addressee_id = b) or (requester_id = b and addressee_id = a)))
$$;

create function is_blocked(a uuid, b uuid) returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (select 1 from friendships
                 where status = 'blocked'
                   and ((requester_id = a and addressee_id = b) or (requester_id = b and addressee_id = a)))
$$;

create function can_view(owner uuid, vis audience) returns boolean
language sql stable security definer set search_path = public
as $$
  select case
    when auth.uid() is not null and owner = auth.uid() then true
    when auth.uid() is not null and is_blocked(owner, auth.uid()) then false
    when vis = 'public' then true
    when vis = 'friends' then auth.uid() is not null and are_friends(owner, auth.uid())
    else false
  end
$$;

-- Whether the viewer may see this Experience (drafts and archived rows are the owner's alone).
create function can_view_experience(e uuid) returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (select 1 from experiences x where x.id = e
                 and (x.owner_id = auth.uid()
                      or (not x.is_draft and x.archived_at is null and can_view(x.owner_id, x.visibility))))
$$;

create function owns_experience(e uuid) returns boolean
language sql stable security definer set search_path = public
as $$ select exists (select 1 from experiences where id = e and owner_id = auth.uid()) $$;

revoke execute on function are_friends(uuid, uuid), is_blocked(uuid, uuid), can_view(uuid, audience),
  can_view_experience(uuid), owns_experience(uuid) from public;
grant execute on function are_friends(uuid, uuid), is_blocked(uuid, uuid), can_view(uuid, audience),
  can_view_experience(uuid), owns_experience(uuid) to authenticated, anon;

alter table experiences enable row level security;
alter table collections enable row level security;
alter table collection_items enable row level security;
alter table media_assets enable row level security;
alter table reflections enable row level security;
alter table participations enable row level security;

create policy experiences_read on experiences for select to authenticated, anon
  using (owner_id = auth.uid() or (not is_draft and archived_at is null and can_view(owner_id, visibility)));
create policy experiences_insert on experiences for insert to authenticated with check (owner_id = auth.uid());
create policy experiences_update on experiences for update to authenticated
  using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy experiences_delete on experiences for delete to authenticated using (owner_id = auth.uid());

create policy collections_read on collections for select to authenticated, anon
  using (owner_id = auth.uid() or can_view(owner_id, visibility));
create policy collections_write on collections for all to authenticated
  using (owner_id = auth.uid()) with check (owner_id = auth.uid());

-- An item shows only when the viewer may see both the collection and the Experience, so a public
-- collection never reveals a private Experience inside it.
create policy collection_items_read on collection_items for select to authenticated, anon
  using (exists (select 1 from collections c where c.id = collection_id
                 and (c.owner_id = auth.uid() or can_view(c.owner_id, c.visibility)))
         and can_view_experience(experience_id));
create policy collection_items_write on collection_items for all to authenticated
  using (exists (select 1 from collections c where c.id = collection_id and c.owner_id = auth.uid()))
  with check (exists (select 1 from collections c where c.id = collection_id and c.owner_id = auth.uid())
              and owns_experience(experience_id));

create policy media_assets_read on media_assets for select to authenticated, anon
  using (owner_id = auth.uid() or (status = 'ready' and can_view_experience(experience_id)));
create policy media_assets_write on media_assets for all to authenticated
  using (owner_id = auth.uid()) with check (owner_id = auth.uid() and owns_experience(experience_id));

create policy reflections_own on reflections for all to authenticated
  using (author_id = auth.uid()) with check (author_id = auth.uid() and can_view_experience(experience_id));

create policy participations_read on participations for select to authenticated
  using (person_id = auth.uid() or owns_experience(experience_id));
create policy participations_owner on participations for all to authenticated
  using (owns_experience(experience_id)) with check (owns_experience(experience_id));

-- 6. From user_experiences to Experiences -------------------------------------------------------------------

-- The catalog's categories, folded into the brief's personal set.
create function life_category(c experience_category) returns text
language sql immutable
as $$
  select case c
    when 'food' then 'food' when 'cafe' then 'food' when 'dessert' then 'food' when 'market' then 'food'
    when 'bar' then 'nightlife' when 'nightlife' then 'nightlife'
    when 'music' then 'music'
    when 'comedy' then 'arts_culture' when 'arts_culture' then 'arts_culture' when 'attraction' then 'arts_culture'
    when 'event' then 'arts_culture'
    when 'outdoors' then 'outdoors'
    when 'sports' then 'sports' when 'active' then 'sports'
    when 'class' then 'learning'
    when 'lodging' then 'travel'
    else 'everyday'
  end
$$;

-- An Experience made from a listing: its title, category and place, with their provenance.
create function experience_from_listing(p_listing uuid, p_owner uuid, p_state experience_state)
returns experiences
language plpgsql security invoker set search_path = public
as $$
declare
  l listings;
  p places;
  tz text;
  e experiences;
begin
  select * into l from listings where id = p_listing;
  select pl.* into p from listing_places lp join places pl on pl.id = lp.place_id
    where lp.listing_id = p_listing and lp.role = 'primary' limit 1;
  select timezone into tz from cities where id = l.city_id;
  insert into experiences (owner_id, state, title, categories, listing_id, city_id, timezone,
                           place_name, place_locality, place_lat, place_lng, place_ref, provenance)
  values (p_owner, p_state, l.title, array[life_category(l.category)], l.id, l.city_id, tz,
          p.name, nullif(concat_ws(', ', p.neighborhood, (select name from cities where id = l.city_id)), ''),
          p.lat, p.lng, p.id,
          jsonb_build_object('title', coalesce(l.provenance ->> 'title', 'curated'),
                             'place', coalesce(l.provenance ->> 'place', 'curated'),
                             'categories', 'estimated'))
  returning * into e;
  return e;
end;
$$;

-- Saved (and not done) → Want; done → Experienced, dated the day it was marked (an estimate of when it happened).
do $$
declare
  r record;
  e experiences;
begin
  for r in select ue.*, c.timezone from user_experiences ue
             join listings l on l.id = ue.experience_id left join cities c on c.id = l.city_id
           where ue.saved_at is not null or ue.done_at is not null loop
    e := experience_from_listing(r.experience_id, r.user_id, case when r.done_at is not null then 'experienced'::experience_state else 'want'::experience_state end);
    update experiences set
      created_at = coalesce(r.saved_at, r.done_at),
      completed_at = r.done_at,
      starts_at = case when r.done_at is not null then r.done_at end,
      time_precision = case when r.done_at is not null then 'day'::time_precision else 'unknown'::time_precision end,
      recommendation_id = r.from_recommendation,
      provenance = provenance || case when r.done_at is not null then '{"time":"estimated"}'::jsonb else '{}'::jsonb end
    where id = e.id;
    if r.rating is not null and r.done_at is not null then
      insert into reflections (experience_id, author_id, rating, rating_scale) values (e.id, r.user_id, r.rating, 3);
    end if;
  end loop;
end;
$$;

-- In-app captures (ADR-012) become media on the Experience they were taken for; still on the phone.
insert into media_assets (owner_id, experience_id, client_id, kind, taken_at, duration_seconds, device_file, status, created_at)
select c.user_id, e.id, c.id, c.kind::text::media_kind, c.taken_at, c.duration_seconds, c.device_media_id, 'on_device', c.created_at
from captures c
join lateral (select x.id from experiences x where x.owner_id = c.user_id and x.listing_id = c.experience_id
              order by x.completed_at desc nulls last limit 1) e on true;
drop table captures;
drop type capture_kind;

-- What's left of user_experiences is taste: interested / not interested, for the recommender.
drop function record_feedback(uuid, text, smallint, uuid);
alter table user_experiences rename to listing_signals;
alter table listing_signals rename column experience_id to listing_id;
alter table listing_signals drop column saved_at, drop column done_at, drop column rating;
alter policy user_experiences_own on listing_signals rename to listing_signals_own;
delete from listing_signals where interested_at is null and not_interested_at is null and from_recommendation is null;

-- One row per listing the person has touched, in the shape clients already read (`experience_id` is the listing).
create view listing_states with (security_invoker = true) as
with mine as (
  select listing_id from experiences where owner_id = auth.uid() and listing_id is not null
  union
  select listing_id from listing_signals where user_id = auth.uid()
)
select
  m.listing_id as experience_id,
  (select min(e.created_at) from experiences e
    where e.owner_id = auth.uid() and e.listing_id = m.listing_id and e.state in ('want', 'planned')) as saved_at,
  s.interested_at,
  s.not_interested_at,
  (select max(e.completed_at) from experiences e
    where e.owner_id = auth.uid() and e.listing_id = m.listing_id and e.state = 'experienced') as done_at,
  (select r.rating from reflections r join experiences e on e.id = r.experience_id
    where e.owner_id = auth.uid() and e.listing_id = m.listing_id and r.author_id = auth.uid()
    order by e.completed_at desc nulls last limit 1) as rating,
  coalesce(s.from_recommendation,
           (select e.recommendation_id from experiences e
             where e.owner_id = auth.uid() and e.listing_id = m.listing_id and e.recommendation_id is not null
             order by e.created_at desc limit 1)) as from_recommendation
from mine m
left join listing_signals s on s.user_id = auth.uid() and s.listing_id = m.listing_id;

-- Feedback on a listing, as before (POST /rest/v1/rpc/record_feedback, p_experience_id = the listing):
--   save → your own Want · unsave → removes that Want if nothing was added to it · done → the Want becomes
--   Experienced, same id (or a new Experienced) · undone → back to Want · rate → your reflection's rating.
create function record_feedback(
  p_experience_id uuid,
  p_action text,
  p_rating smallint default null,
  p_recommendation_id uuid default null
) returns listing_states
language plpgsql security invoker set search_path = public
as $$
declare
  me uuid := auth.uid();
  target experiences;
  result listing_states;
  from_rec boolean;
begin
  if me is null then
    raise exception 'Not signed in' using errcode = '28000';
  end if;
  if p_action not in ('save', 'unsave', 'interested', 'not_interested', 'done', 'undone', 'rate') then
    raise exception 'Unknown action "%"', p_action using errcode = '22023';
  end if;
  -- RLS on listings hides drafts and other people's private rows.
  if not exists (select 1 from listings where id = p_experience_id) then
    raise exception 'Experience not found' using errcode = 'P0002';
  end if;

  if p_action in ('interested', 'not_interested') then
    insert into listing_signals (user_id, listing_id) values (me, p_experience_id)
    on conflict (user_id, listing_id) do nothing;
    update listing_signals set
      interested_at     = case p_action when 'interested' then now() else null end,
      not_interested_at = case p_action when 'not_interested' then now() else null end,
      from_recommendation = coalesce(p_recommendation_id, from_recommendation),
      updated_at = now()
    where user_id = me and listing_id = p_experience_id;

  elsif p_action = 'save' then
    if not exists (select 1 from experiences where owner_id = me and listing_id = p_experience_id and state in ('want', 'planned')) then
      target := experience_from_listing(p_experience_id, me, 'want');
      update experiences set recommendation_id = p_recommendation_id where id = target.id and p_recommendation_id is not null;
    end if;

  elsif p_action = 'unsave' then
    delete from experiences e where e.owner_id = me and e.listing_id = p_experience_id and e.state = 'want'
      and not exists (select 1 from media_assets m where m.experience_id = e.id)
      and not exists (select 1 from reflections r where r.experience_id = e.id
                      and (r.rating is not null or r.body is not null or r.favorite_moment is not null));

  elsif p_action = 'done' then
    if not exists (select 1 from experiences where owner_id = me and listing_id = p_experience_id and state = 'experienced') then
      select * into target from experiences
        where owner_id = me and listing_id = p_experience_id and state in ('want', 'planned', 'in_progress')
        order by created_at limit 1;
      if target.id is null then
        target := experience_from_listing(p_experience_id, me, 'want');
      end if;
      update experiences set
        state = 'experienced',
        starts_at = coalesce(starts_at, now()),
        time_precision = case when starts_at is null then 'day' else time_precision end,
        provenance = provenance || case when starts_at is null then '{"time":"estimated"}'::jsonb else '{}'::jsonb end,
        recommendation_id = coalesce(p_recommendation_id, recommendation_id)
      where id = target.id
      returning recommendation_id is not null into from_rec;
    end if;

  elsif p_action = 'undone' then
    select * into target from experiences
      where owner_id = me and listing_id = p_experience_id and state = 'experienced'
      order by completed_at desc limit 1;
    if target.id is not null then
      update experiences set state = 'want', starts_at = null, ends_at = null, time_precision = 'unknown',
             provenance = provenance - 'time'
      where id = target.id;
      update reflections set rating = null where experience_id = target.id and author_id = me;
    end if;

  elsif p_action = 'rate' then
    select * into target from experiences
      where owner_id = me and listing_id = p_experience_id and state = 'experienced'
      order by completed_at desc limit 1;
    if target.id is null then
      raise exception 'Mark it done before rating it' using errcode = '22023';
    end if;
    if p_rating is null or p_rating not between 1 and 3 then
      raise exception 'Rating must be 1, 2 or 3' using errcode = '22023';
    end if;
    insert into reflections (experience_id, author_id, rating, rating_scale) values (target.id, me, p_rating, 3)
    on conflict (experience_id, author_id) do update set rating = excluded.rating, rating_scale = 3, updated_at = now();
  end if;

  insert into events (user_id, name, props) values (
    me,
    case p_action when 'save' then 'saved' when 'unsave' then 'unsaved' when 'done' then 'did_it' when 'undone' then 'undid_it'
                  when 'rate' then 'rated' else p_action end,
    jsonb_strip_nulls(jsonb_build_object(
      'experience_id', p_experience_id,
      'rating', case when p_action = 'rate' then p_rating end,
      'recommendation_id', p_recommendation_id,
      'from_recommendation', from_rec
    ))
  );

  select * into result from listing_states where experience_id = p_experience_id;
  if result.experience_id is null then
    result.experience_id := p_experience_id;      -- nothing left (e.g. unsaved): an empty state, not an error
  end if;
  return result;
end;
$$;

revoke execute on function record_feedback(uuid, text, smallint, uuid) from public, anon;
grant execute on function record_feedback(uuid, text, smallint, uuid) to authenticated;
revoke execute on function experience_from_listing(uuid, uuid, experience_state) from public, anon;
grant execute on function experience_from_listing(uuid, uuid, experience_state) to authenticated;

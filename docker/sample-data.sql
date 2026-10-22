-- Local sample data so the recommender has something to return before the real catalog is reviewed.
-- Never loaded on the hosted project. Every fact is unverified, so every field is marked `estimated`.
-- Ids start with 5a5a5a5a so they can't collide with catalog ids (UUIDv5 from tools/catalog/build-seed.ts).

create temp table sample_rows (n, title, intent, category, tags, good_for, pmin, pmax, dmin, dmax, gmin, gmax, hours, place, hood, lat, lng) as values
  (1, 'Stand-up at Punch Line Philly', 'Catch a stand-up comedy show', 'comedy', '{comedy}', '{date,friends,group}', 2500, 4000, 90, 120, 1, 8,
   '[{"day":3,"open":"19:00","close":"23:30"},{"day":4,"open":"19:00","close":"23:30"},{"day":5,"open":"19:00","close":"01:00"},{"day":6,"open":"18:00","close":"01:00"},{"day":0,"open":"18:00","close":"22:30"}]',
   'Punch Line Philly', 'Fishtown', 39.9686, -75.1355),
  (2, 'Sunset walk on the Schuylkill River Trail', 'Walk the river trail at golden hour', 'outdoors', '{walk,views}', '{solo,date,friends,family}', 0, 0, 45, 120, 1, 10,
   '[]', 'Schuylkill Banks', 'Center City', 39.9496, -75.1810),
  (3, 'Lunch crawl at Reading Terminal Market', 'Graze your way through the market', 'market', '{food,local}', '{solo,friends,family,group}', 1500, 3000, 60, 90, 1, 6,
   '[{"day":0,"open":"08:00","close":"18:00"},{"day":1,"open":"08:00","close":"18:00"},{"day":2,"open":"08:00","close":"18:00"},{"day":3,"open":"08:00","close":"18:00"},{"day":4,"open":"08:00","close":"18:00"},{"day":5,"open":"08:00","close":"18:00"},{"day":6,"open":"08:00","close":"18:00"}]',
   'Reading Terminal Market', 'Chinatown', 39.9533, -75.1590),
  (4, 'Philadelphia Museum of Art', 'See the collection and run the Rocky steps', 'arts_culture', '{museums,views}', '{solo,date,friends,family}', 3000, 3000, 120, 180, 1, 10,
   '[{"day":1,"open":"10:00","close":"17:00"},{"day":4,"open":"10:00","close":"17:00"},{"day":5,"open":"10:00","close":"20:45"},{"day":6,"open":"10:00","close":"17:00"},{"day":0,"open":"10:00","close":"17:00"}]',
   'Philadelphia Museum of Art', 'Fairmount', 39.9656, -75.1810),
  (5, 'Arcade games and drinks at Barcade', 'Play classic arcade games over a beer', 'games', '{games,bars}', '{date,friends,group}', 1500, 4000, 90, 180, 1, 8,
   '[{"day":0,"open":"12:00","close":"02:00"},{"day":1,"open":"16:00","close":"02:00"},{"day":2,"open":"16:00","close":"02:00"},{"day":3,"open":"16:00","close":"02:00"},{"day":4,"open":"16:00","close":"02:00"},{"day":5,"open":"12:00","close":"02:00"},{"day":6,"open":"12:00","close":"02:00"}]',
   'Barcade', 'Fishtown', 39.9672, -75.1342),
  (6, 'Live jazz at Chris'' Jazz Cafe', 'Hear a live jazz set', 'music', '{live_music,jazz}', '{solo,date,friends}', 2000, 4000, 90, 150, 1, 6,
   '[{"day":2,"open":"18:00","close":"00:00"},{"day":3,"open":"18:00","close":"00:00"},{"day":4,"open":"18:00","close":"00:00"},{"day":5,"open":"18:00","close":"01:00"},{"day":6,"open":"18:00","close":"01:00"}]',
   'Chris'' Jazz Cafe', 'Center City', 39.9479, -75.1677),
  (7, 'Wheel-throwing pottery class', 'Make a bowl on the wheel in a beginner class', 'class', '{classes,creative}', '{solo,date,friends}', 6000, 9000, 120, 150, 1, 4,
   '[{"day":6,"open":"11:00","close":"16:00"},{"day":0,"open":"11:00","close":"16:00"},{"day":3,"open":"18:30","close":"21:00"}]',
   'The Clay Studio', 'South Kensington', 39.9722, -75.1391),
  (8, 'Late-night cheesesteak in South Philly', 'Settle the Pat''s vs Geno''s debate yourself', 'food', '{food,late_night}', '{solo,friends,group}', 1200, 2000, 20, 45, 1, 8,
   '[{"day":0,"open":"11:00","close":"03:00"},{"day":1,"open":"11:00","close":"03:00"},{"day":2,"open":"11:00","close":"03:00"},{"day":3,"open":"11:00","close":"03:00"},{"day":4,"open":"11:00","close":"03:00"},{"day":5,"open":"11:00","close":"03:00"},{"day":6,"open":"11:00","close":"03:00"}]',
   'East Passyunk & 9th', 'South Philadelphia', 39.9335, -75.1590)
;

insert into listings (id, city_id, visibility, status, title, intent, category, tags, good_for, location_requirement,
                           price_min_cents, price_max_cents, duration_min_minutes, duration_max_minutes, group_min, group_max,
                           hours, provenance, review_note)
  select ('5a5a5a5a-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid, 'philadelphia', 'catalog', 'published', title, intent,
         category::experience_category, tags::text[], good_for::occasion[], 'exact', pmin, pmax, dmin, dmax, gmin, gmax,
         hours::jsonb,
         '{"title":"estimated","intent":"estimated","category":"estimated","tags":"estimated","good_for":"estimated","price_min_cents":"estimated","price_max_cents":"estimated","duration_min_minutes":"estimated","duration_max_minutes":"estimated","group_min":"estimated","group_max":"estimated","hours":"estimated"}'::jsonb,
         'Local sample data (docker/sample-data.sql), not part of the catalog'
  from sample_rows
  on conflict (id) do update set title = excluded.title, intent = excluded.intent, category = excluded.category, tags = excluded.tags,
    good_for = excluded.good_for, price_min_cents = excluded.price_min_cents, price_max_cents = excluded.price_max_cents,
    duration_min_minutes = excluded.duration_min_minutes, duration_max_minutes = excluded.duration_max_minutes,
    group_min = excluded.group_min, group_max = excluded.group_max, hours = excluded.hours, provenance = excluded.provenance,
    updated_at = now();

insert into places (id, city_id, provider, provider_place_id, name, neighborhood, lat, lng)
  select ('5a5a5a5a-0000-4000-9000-' || lpad(n::text, 12, '0'))::uuid, 'philadelphia', 'manual', 'sample:' || n, place, hood, lat, lng
  from sample_rows
  on conflict (id) do update set name = excluded.name, neighborhood = excluded.neighborhood, lat = excluded.lat, lng = excluded.lng;

insert into listing_places (listing_id, place_id, role)
select ('5a5a5a5a-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid, ('5a5a5a5a-0000-4000-9000-' || lpad(n::text, 12, '0'))::uuid, 'primary'
from sample_rows
on conflict do nothing;

#!/usr/bin/env bash
# Applies new files in supabase/migrations (tracked like the Supabase CLI does), then the seeds.
# Runs on every `docker compose up`; already-applied migrations are skipped and the seeds are upserts.
set -euo pipefail

until pg_isready -q; do sleep 1; done
psql() { command psql -v ON_ERROR_STOP=1 -q "$@"; }

psql -c "create schema if not exists supabase_migrations;
         create table if not exists supabase_migrations.schema_migrations (version text primary key, name text, statements text[]);"

for f in /supabase/migrations/*.sql; do
  base=$(basename "$f" .sql)
  version=${base%%_*}
  if [ "$(psql -tAc "select 1 from supabase_migrations.schema_migrations where version = '$version'")" = "1" ]; then
    continue
  fi
  echo "applying $base"
  psql --single-transaction -f "$f" -c "insert into supabase_migrations.schema_migrations (version, name) values ('$version', '${base#*_}')"
done

if [ -f /supabase/seed.sql ]; then
  echo "applying supabase/seed.sql"
  psql --single-transaction -f /supabase/seed.sql
fi

if [ "${LOCAL_PUBLISH_DRAFTS}" = "true" ]; then
  # Local only: show AI-researched drafts in the app. Their facts stay `estimated`, so the UI labels them.
  echo "publishing catalog drafts locally (LOCAL_PUBLISH_DRAFTS=false to skip)"
  psql -c "update experiences set status = 'published' where status = 'draft' and visibility = 'catalog'"
fi

if [ "${SAMPLE_DATA}" = "true" ]; then
  echo "applying docker/sample-data.sql (set SAMPLE_DATA=false to skip)"
  psql --single-transaction -f /sample-data.sql
else
  psql -c "delete from experiences where id::text like '5a5a5a5a-%'; delete from places where id::text like '5a5a5a5a-%';"
fi

# PostgREST caches the schema; tell it to pick up new tables and functions.
psql -c "notify pgrst, 'reload schema'"
echo "database ready"

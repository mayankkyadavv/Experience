# Experience

An iOS app that helps you and your friends answer **"What should we do?"** in your city, then go do it. Philadelphia is the beta. Start with `CLAUDE.md` and `docs/MVP.md`.

## Run the backend locally

Needs [Docker Desktop](https://www.docker.com/products/docker-desktop/). Nothing else.

```sh
docker compose up -d                              # first run pulls images (~3 GB) and takes a few minutes
docker compose run --rm tools deno task smoke     # sign up, pick Philadelphia, get three recommendations
```

| What | Where |
|---|---|
| API (auth, REST, Edge Functions) | `http://localhost:54321` (`/auth/v1`, `/rest/v1`, `/functions/v1`) |
| Postgres | `postgresql://postgres:postgres@localhost:54322/postgres` |
| Studio (tables, SQL editor) | http://localhost:54323 |
| Anon key | in `compose.yaml` (`ANON_KEY`); local only |

`docker compose up` applies new files in `supabase/migrations/`, then `supabase/seed.sql` (the reviewed catalog), then eight **sample** Philadelphia Experiences from `docker/sample-data.sql`, all marked `(estimated)`, so the recommender returns something before the catalog is reviewed. Turn them off with `SAMPLE_DATA=false docker compose up -d`.

Edge Functions in `supabase/functions/` are live-mounted: save a file and the next request runs the new code. Local sign-in is email + password, auto-confirmed (Sign in with Apple needs the hosted project).

### Everyday commands

```sh
docker compose run --rm tools                     # Deno tests (recommender + schema/RLS)
docker compose run --rm tools deno task smoke --when weekend --hours 4 --budget any --who date --mood something_new
docker compose run --rm tools deno task catalog:check
docker compose logs -f functions                  # Edge Function logs
docker compose up -d migrate                      # apply a new migration without restarting
docker compose down                               # stop (data kept)
docker compose down -v                            # stop and wipe the database
```

With Deno installed on your Mac, the same tasks run directly (`deno task test`, `deno task smoke`).

## Not in Docker

- **The iOS app** needs Xcode and the iOS Simulator (macOS only). It will point at `http://localhost:54321` in debug builds.
- **`ExperienceCore` Swift tests:** `ios/Packages/ExperienceCore/test.sh` (or `swift test` once Xcode is installed).
- **Production** is hosted Supabase (ADR-002): migrations and functions deploy with the Supabase CLI. The local stack runs the same open-source services, so what works here works there.

## Layout

```
ios/            SwiftUI app + share extension (Week 2), ExperienceCore package
supabase/       migrations, Edge Functions, schema tests
catalog/        Philadelphia catalog entries (JSON, reviewed by hand)
tools/          catalog drafter/seed builder, smoke test
docker/         local-only config for compose.yaml
spikes/         throwaway prototypes (identification)
docs/           MVP, architecture, ADRs, build plan
```

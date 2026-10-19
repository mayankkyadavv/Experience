# ADR-002: Supabase is the whole backend

- **Status:** Accepted (2026-10-18) · **Ledger:** D3, R11, R16

## Context
A solo founder needs something flexible to change, reliable, and cheap. No separate API server.

## Decision
One Supabase project: Auth (Sign in with Apple), Postgres with row-level security on every table, Edge Functions (`identify`, later `digest`), a `jobs` table plus `pg_cron` for queueing, retries and schedules, and APNs push sent from Edge Functions over HTTP/2 with a `device_tokens` table. Free tier while building; upgrade to **Pro (~$25/mo) on the day of the first TestFlight build**, because the free tier pauses after 7 idle days.

## Consequences
- Edge Function time limits: identification must be a resumable job (ADR-005).
- Everything is Postgres, which makes it easy to inspect and back up.
- Vendor lock-in is moderate: plain Postgres plus Deno TypeScript functions port elsewhere.

## Revisit when
Job volume or function limits become a real bottleneck.

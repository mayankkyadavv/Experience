# ADR-005: Identification as queued jobs: metadata → Claude → place search

- **Status:** Accepted (2026-10-18) · **Ledger:** R2, R3, R15, R7a, R7b

## Context
LLM and places calls can exceed Edge Function limits and fail mid-way. Identification must never silently drop a save, and uncertainty must be visible.

## Decision
- A `sources` insert creates a `jobs` row. An insert trigger calls `identify` immediately (R15); `pg_cron` picks up retries. 3 attempts with exponential backoff, then `needs_review` (R2).
- Steps: resolve short links → legal signals (ADR-004) → **Claude structured extraction** (`claude-opus-5-5`, a Zod schema via structured outputs, server-side refusal fallback) → place search (ADR-003) → name-match check → confidence.
- Output per source: one or more Experiences (ADR-006), candidate interpretations with evidence quotes, confidence. All of it is written with job completion in **one transaction**. A retry never creates a second set and never overwrites `user`-provenance fields.
- Auto-pin at ≥ 0.8 with a solid match (a default, tuned from the eval). Otherwise one question, pushed only within 5 minutes of the share (R7a), or the "Needs a place" queue.
- **Identify per save** (R3 reversed): no cross-user cache by URL, because it would leak one user's hint to others and is premature at ~35 users.
- Captions are treated as untrusted input; the prompt ignores instructions inside them.

## Consequences
- Each save costs one Claude call (cents).
- Every result is evaluable: the eval scores place, activity, count and calibration (ARCHITECTURE.md).

## Revisit when
Cost per save matters (after Gate 2): reconsider a per-URL cache that excludes user hints.

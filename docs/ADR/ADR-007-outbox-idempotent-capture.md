# ADR-007: Outbox capture with idempotent save_id

- **Status:** Accepted (2026-10-18), amended by ADR-006 · **Ledger:** R1 (owner), R4

## Context
"Capture can never lose a save." Retries give at-least-once delivery, which would create duplicate saves without a dedupe key.

## Decision
- The share extension writes to the App Group **outbox before uploading**, with a client-generated **`save_id` UUID**. It shows "Saved" immediately and retries until the server confirms. Nothing leaves the outbox before confirmation.
- The server has a unique index **`(user_id, save_id)` on `sources`** (moved from the Experience row by ADR-006). The insert is upsert-ignore; a replay returns the existing source row. Identification runs once per source (ADR-005).
- The extension never refreshes tokens. With an expired token it just queues (R4).

## Consequences
- Test: replaying the same outbox item twice yields one source and one set of Experiences.
- The "Syncing N saves" banner shows while the outbox isn't empty.

## Revisit when
Never, while capture is the product's front door.

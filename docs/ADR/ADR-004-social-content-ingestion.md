# ADR-004: Social ingestion: URL-first, legal metadata only, never download video

- **Status:** Accepted (2026-10-18) · **Ledger:** R7e, R12, R13; CLAUDE.md non-negotiables

## Context
Platforms forbid re-hosting, and scraping is fragile and against their terms. Instagram oEmbed is "for embedding only", and Meta removed author and thumbnail fields in Nov 2025.

## Decision
- Store the **URL and extracted metadata only**. Never download or re-host video. Display only through official embeds.
- **TikTok/YouTube:** use only legally usable metadata (oEmbed caption/title/author; the YouTube Data API description, tags and recording location). Whether oEmbed data may be used as extraction input is an open M0 terms check.
- **Instagram: URL-only.** Never fetch from Meta. The share extension asks "What place is this?" (skippable) with on-device `MKLocalSearchCompleter`. Any platform without legally usable metadata uses this same flow.
- The extension pulls the first URL from shared text. The server resolves short links (e.g. `vm.tiktok.com`) before identification.
- **Thumbnails** are not used for extraction until the terms check allows it. If allowed, they're fetched transiently, sent to the model, and never stored or re-served.

## Consequences
- Instagram identification depends on the user's hint.
- Transcript and video-vision extraction are off the table unless this ADR is superseded (founder decision; see MVP.md).

## Revisit when
The terms check concludes, or a platform offers an official API for captions or transcripts.

# MVP: current build scope

**Updated 2026-10-20 (ADR-013).** The product is now defined by `EXPERIENCES_PRODUCT.md`. This file maps its **Stages 0-2** onto this codebase. If something isn't in the brief's Stages 0-2, it's out of scope. Precedence is in CLAUDE.md. The previous city-first scope ("What should we do?" → three recommendations) is superseded; see git history and `docs/EXPERIENCE.md` (historical).

## What we're building

A personal life archive the creator uses every week, then friends: **capture what you lived, keep what you want to do, plan it, live it, revisit it.** One Experience object across its whole life (brief §3-5).

The standard for "done" is the brief's §25, not engagement: does the creator voluntarily save ordinary moments, find a half-remembered evening fast, know exactly who sees what, turn discovery into plans, and leave with their history intact?

## Stage 0: skeleton and prototypes (now)

- The Experience contract in code: stable ID, owner, `state` (want / planned / in_progress / experienced / cancelled), separate draft and archived flags, `visibility` (private / friends / public), time with precision and original timezone, ordered places, moments, media references, participation, per-person reflection and rating, `inspired_by` / source listing, field provenance.
- Authorization policy and audience labels designed once (brief §9) and enforced by RLS.
- Navigation: **Life · Discover · Plans · You**, **+** everywhere, search. Life: Overview / Timeline / Map / Calendar.
- Prototype both loops end to end with clearly labelled sample histories (sparse, ordinary, large, uncertain dates, shared): capture → detail → Life → map, and discover → Want → plan → Experienced.
- Decide before real private media is ingested: media storage, export format, deletion and processing disclosures.
- Design pass: explore several Life layouts against sparse, dense, media-free and decade-long histories (brief §20) before extending DESIGN.md.

**Ready when** the full loop works in the prototype with no fork between a shared post and a remembered Experience.

## Stage 1: a dependable personal archive

- Account and profile basics (Sign in with Apple, ADR-002). Owner profile centered on the confirmed Experience count.
- **Capture** (brief §6): + → photos/video (existing camera, ADR-012, plus the photo library), a short thought, or **Add without media** → draft with proposed title, time and place (provenance visible) → **Save privately**. No required rating, caption, category, place, people or sharing decision. Works offline; saves before AI or upload finish; visible states ("Saved on this device; waiting to upload"); retries never duplicate.
- Experience detail: cover or text-first treatment, title, time, place, people, plainly visible audience, moments/media, reflection. Actions by state (Experienced: Add a moment, Reflect, Share; Want: Plan this, Edit; Planned: Add photos / Mark experienced).
- Editable time (exact / day / month / year / range / unknown) and place; "Date unknown" area.
- Media: originals kept separate from derivatives; durable private storage (open decision 1).
- Timeline, basic map with a synchronized list, lexical search over titles, dates, places, people, categories, notes.
- **Want** and **Planned** states on the same object. Saving a catalog listing (existing Philadelphia catalog) or a shared TikTok link creates a private Want linked to it.
- Reflection invitation ("What do you want to remember?"), optional 1-5 rating with no default, Would do again, favorite moment. All private by default.
- **Export:** versioned JSON + media + manifest + Markdown summaries.
- Empty states as in brief §19; onboarding offers Add a recent Experience / Save something I want to do / Explore first. Permissions asked one at a time, in context.

**Ready when** the creator can record a month of ordinary life, find a memory by date, place or text, correct it, and export it without losing media or context.

## Stage 2: the core MVP loop (the MVP boundary)

- Mutual friendships (Add friend / Request sent / Friends), block, mute, unfriend.
- Private / Friends (all accepted friends) / Public on each Experience; audience preview ("What would a friend or public visitor see?"); public location precision.
- Basic public profile; permission-aware counts ("31 public Experiences"); optional "Show my total count".
- **Discover:** finite Friends feed (recent first, one card per shared outing, "You're caught up"), public Experience browsing, and **Things you could do** from the curated catalog, honestly labelled. **Want to Experience** from any of them creates your own Want.
- Basic planning: date, meeting place, invited friends, notes, optional stops; invitee accepts or declines; each participant confirms their own attendance; "Did you go?" after the time passes.
- Simple month recap referencing Experiences (public sharing only of Public content).
- Reporting and blocking before anything is public. Revocation works across media, search, counts and caches.

**Ready when** the creator can discover an idea, save it, plan it, do it, capture it, share the same object, and revisit it on timeline and map, and another account sees exactly the intended subset.

## What carries over from the city-first build

| Existing | Becomes |
|---|---|
| Camera capture (ADR-012), `captures` table | Media capture into a draft Experience; `captures` folds into media assets |
| Philadelphia catalog (`experiences`, `experience_places`, links, occurrences; ADR-009/011) | Reference listings for **Things you could do**; saving creates a personal Experience |
| `user_experiences` (saved / interested / not interested / done, rating) | Migrated to personal Experiences (Want / Experienced) + per-person rating; can't represent repeat visits |
| Recommender (`supabase/functions/recommend/`) | Optional "Worth a look" on Life and Discover; no longer the home screen |
| TikTok share extension + identify (ADR-004/005/007) | A shared link becomes a proposed Want, with provenance |
| `friendships`, `groups` tables (ADR-011) | Friendships used in Stage 2; groups wait for Stage 3 |
| White 3D city map (ADR-010, DESIGN.md) | The Life → Map view; Experiences, not pins or location trails |
| `Sourced<T>` / `SourcedText` | Unchanged; the brief's field provenance |

## Not in scope (Stages 3-5 and deferred)

Selected-friend audiences, collaborative contributions and consent, group availability voting, Ask Experiences and semantic search, capture clustering, recap films, memory reconstruction, gamification, broad email/receipt ingestion, face recognition, continuous location, booking/payments, messaging, multi-owner permissions, Android, desktop/web.

## Open decisions (founder)

1. **Media storage.** Default proposal: originals upload to private Supabase Storage (signed, short-lived URLs; location metadata stripped from served derivatives), with the on-device copy kept until upload is confirmed. This changes ADR-012's "media stays on device" and is a privacy disclosure.
2. **What the app opens to.** The brief's Life overview, or keep ADR-012's camera as the first screen with Life one tap away.
3. **Rating scale:** the brief proposes an optional 1-5; the current UI has three tiles.
4. Final name (Experiences is the working name).

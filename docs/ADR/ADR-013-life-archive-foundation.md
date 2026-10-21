# ADR-013: Experiences is a personal life archive (the product brief governs)

- **Status:** Accepted (2026-10-20, founder) · **Supersedes:** the city-first "What should we do?" strategy (`docs/EXPERIENCE.md`, the 2026-10-18 MVP) · **Amends:** ADR-006, ADR-009, ADR-011, ADR-012 · **Brief:** `EXPERIENCES_PRODUCT.md`

## Context
The founder rewrote what the app is: "Experiences is a beautiful, intelligent, evolving representation of the life a person has actually lived, and the experiences they still want to have." The brief replaces the business framing (market fit, competitors, the "will they open it?" hypothesis, a recommendation north star) with a personal, decades-long standard: an app the creator is proud of and wants to use for twenty years. It answers three questions: what have I experienced, what are the people I care about experiencing, what should I experience next.

## Decision
- `EXPERIENCES_PRODUCT.md` is the governing product brief. Product meaning (identity, lifecycle, privacy, ownership, retention) comes from it. ADRs still govern technical choices that don't contradict it.
- **The Experience is one object across its life** (brief §3-4): Want → Planned → (In progress) → Experienced, or Cancelled. Same ID from saved idea to memory to feed card to recap. "Memory" and "post" are views, not tables. A repeat visit is a new Experience.
- **The personal Experience is the root.** The Philadelphia catalog becomes **reference listings** ("Things you could do", brief §10): saving one creates the person's own Experience linked to it. This reverses ADR-009's "user ↔ catalog row" model for personal history.
- **Private by default** for everything new (captures, imports, AI suggestions, wants). Three levels: Private / Friends / Public, with one access policy applied to every surface (brief §9).
- **Capture** (ADR-012's camera stays) is one way into the default capture flow: + from anywhere → photos/video, text, or no media → draft → **Save privately** (brief §6). Text-only, undated and place-less Experiences are first class. Saving never waits for AI or upload.
- **Scope = Stages 0-2** (brief §23): dependable personal archive, then friends, visibility, feed, discovery → Want → plan → Experienced, month recap, export.
- TikTok sharing, identification (ADR-004/005/008) and the recommender stay as inputs: a shared link or a recommendation becomes a Want.

## Consequences
- **Schema change needed before more UI:** a personal `experiences` model with `owner_id`, `state`, time with precision/timezone, `visibility`, moments, media assets, participation and per-person reflections; catalog rows become listings referenced by `source listing` / `inspired_by`. `user_experiences` (one row per user per catalog entry) can't represent repeat visits or Want → Experienced identity, so it's migrated, not extended. Design in a new migration; no real user data exists yet.
- **Media durability (ADR-012 amended):** media on the device only conflicts with "the archive must last" and export. Originals need a durable, private home (Supabase Storage with signed short-lived URLs is the default proposal) before real history accumulates. Cloud upload of personal media is a privacy disclosure; the founder confirms the default.
- **Export** (versioned JSON + media + manifest + Markdown) is a Stage 1 requirement, not later.
- Friends, feed, comments/reactions, visibility, basic planning and profiles move from "not building yet" into Stage 2. Leaderboards, streaks, booking, messaging, face recognition and continuous location stay out.
- The recommender's "three picks" stops being the home screen; it can feed **Worth a look** and Discover.
- DESIGN.md was built for "one big question, three answers"; its tokens stand, but screen-level direction (Life, Timeline, Map, Calendar, detail) needs a new design pass (brief §20 asks for several Life layouts).
- Success is judged by the brief's §25 questions, not DAU, session length or a done-per-month north star.

## Revisit when
The founder changes the brief. Changes to identity, privacy meaning, ownership or retention are product-contract changes and must be surfaced to the founder.

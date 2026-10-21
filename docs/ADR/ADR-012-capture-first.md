# ADR-012: Capture-first: the camera is the home screen

- **Status:** Accepted (2026-10-19, founder) · **Amends:** MVP.md core loop (capture becomes the center; "What should we do?" and your city stay) · **Design:** DESIGN.md "Camera"

## Context
The founder: "I really want the core of the application to be an app that captures your experience in the most convenient way. This ties into your city being filled… but I want this to be the core. The first thing a user sees after setup is the camera, very similar to Snapchat." Until now the center was the "What should we do?" question, with TikTok sharing as the input loop and "Did it" as the only way an Experience entered your city.

## Decision
- After onboarding, the app opens to a **full-screen camera**. Calm chrome: one circular shutter (tap = photo, hold = video up to 60 s), pinch or drag-up-while-recording to zoom, lens presets (0.5× / 1× / 2× when the device has them), tap to focus, double-tap to flip, flash.
- A capture goes to a **review** (retake or keep), then **"Where was this?"**: catalog Experiences near where it was taken, closest first, plus search and "Not on the list". Choosing one records the capture against that Experience and marks it **done**, so a pillar rises on your city. A capture without a place is still kept.
- **Media stays on the device** (the app's documents folder). The server stores only a `captures` row: kind, time, duration, the linked Experience. No capture coordinates leave the phone. Cloud backup of media is a later, explicit decision (Supabase Storage, cost and privacy).
- Your city and "What should we do?" are one tap from the camera; the city view has a camera button back.
- The camera needs a real iPhone; the Simulator shows a placeholder and the rest of the flow is tested there.

## Consequences
- North star candidate shifts toward **Experiences captured (done) per active user per week**; the founder confirms.
- TikTok share capture stays (MVP), as a second input.
- `captures` table with owner-only RLS (migration `20261022000000_captures.sql`).

## Revisit when
People open the app to decide what to do far more than to capture, or on-device-only media blocks a feature testers ask for (sharing, multi-device).

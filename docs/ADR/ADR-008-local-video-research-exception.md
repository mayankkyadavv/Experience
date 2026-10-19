# ADR-008: Local research exception for video analysis

- **Status:** Accepted (2026-10-18) · **Narrows:** ADR-004 (research only; the product rule is unchanged) · **Decided by:** founder

## Context
ADR-004 forbids downloading platform video. The eval's richest arms (transcript, frames, on-screen text) need the video, and the founder wants to see everything that can be decoded from a reel before designing the production pipeline.

## Decision
`spikes/identify` (the local decoder) may analyze TikTok and YouTube videos **on the founder's Mac only**:
- The video is downloaded (yt-dlp, ≤ 720p) into a temp directory that's **deleted at the end of every run**. Frames and audio are never kept or uploaded. The run log (`runs/`, gitignored) holds only derived text.
- Speech-to-text runs on-device (whisper.cpp), and on-screen text uses Apple Vision on-device. Frames may be sent to the chosen model (a local model via Ollama, or Claude) only within that run.
- **Instagram stays URL-only.** Its video is never fetched (CLAUDE.md non-negotiable).
- None of this ships. The production `identify` function and the iOS app still follow ADR-004.

## Consequences
- We can measure how much transcript and frames improve identification (eval arms 4-5) before deciding anything for production.
- The terms exposure is limited to local, transient research by the founder. Putting any of this into the product needs a new ADR that supersedes ADR-004.

## Revisit when
The eval shows video signals matter enough to pursue a product path (official APIs, user-side processing, or a terms review).

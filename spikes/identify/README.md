# Local decoder (research, ADR-008)

Paste a TikTok, YouTube Short or Instagram Reel link and see everything we can decode from it, stage by stage. It all runs on this Mac.

```
link → public metadata → video (temporary) → speech to text + frames/on-screen text → understanding → places
```

## Run

```sh
cd spikes/identify
npm install
npm run setup     # once: brew installs yt-dlp, ffmpeg, whisper-cpp; downloads the Whisper model (~1.6 GB); pulls gemma3:12b if Ollama is running
npm run serve     # → http://localhost:4321
```

Optional `.env` (copy `.env.example`): `ANTHROPIC_API_KEY` enables Claude in the model picker; `YOUTUBE_API_KEY` adds YouTube descriptions without downloading; `APPLE_MAPS_AUTH_TOKEN` switches place search from OpenStreetMap to Apple Maps.

Command-line version, same pipeline:

```sh
npm run identify -- "<link>" [--model gemma3:12b|claude] [--hint "Joe's Pizza"] [--no-video] [--no-frames] [--json]
```

## What each stage does

| Stage | How | Where it runs |
|---|---|---|
| Link | Platform, post id, short-link resolution | Local (+ a redirect lookup) |
| Public metadata | TikTok/YouTube oEmbed (caption, author, hashtags); YouTube Data API if keyed | TikTok/YouTube servers |
| Video | `yt-dlp` ≤ 720p into a temp dir, plus its info JSON (description, music, tags, location) | Download, then local |
| Speech to text | `whisper.cpp` large-v3-turbo on the GPU, language auto-detected | Local |
| Frames + on-screen text | 8 evenly spaced frames via `ffmpeg`; text read by Apple Vision (`ocr.swift`) | Local |
| Understanding | Ollama model (local) or Claude: Experiences with title, intent, category, location requirement, place candidates, evidence | Local, or Anthropic's cloud for Claude |
| Places | OpenStreetMap Nominatim (or Apple Maps with a token) | OpenStreetMap / Apple |

**Rules kept:** the temp directory (video, audio, frames) is deleted at the end of every run. Instagram's video is never fetched (URL-only).

**Instagram links** work the way the share extension will: pasting one opens "What place is this?" with place autocomplete (Photon, or Apple Maps with a token). Pick a suggestion and its name and coordinates become a `user` hint. The place is confirmed and pins with no lookup, and the model still writes the title and category, labelled estimated. You can also type free text and press Return to have it looked up, or Skip to send it to "Needs a place". Each answer is timed from the moment the link arrives, against the < 10 s target, and logged as `question` (`picked` / `typed` / `skipped`, `ms`) in `runs.jsonl`. "Rank places near me" biases suggestions to your location, as `MKLocalSearchCompleter` does. Each run's derived text is appended to `runs/runs.jsonl` (gitignored).

## Reading the results

Every field shows where it came from: `source` (read from the post: caption, speech, on-screen text, frames), `user` (your hint), `lookup` (map provider), `estimated` (the model's guess, always labelled "(estimated)").

Confidence is lowered when the map match is weak (×0.75) or missing (×0.6). The result is one of:
- pin automatically (≥ 0.8 with a solid match)
- ask the user
- "Needs a place"
- saved as flexible
- saved as an idea

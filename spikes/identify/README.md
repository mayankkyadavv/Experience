# Identification spike (Phase 0, throwaway)

Paste a TikTok, YouTube Short or Instagram Reel link and see what the identify pipeline can work out: place name, type, address, coordinates, confidence, and where each field came from.

```
link → platform + short-link resolution → public metadata → Claude extraction → place search → result
```

## Run

```sh
cd spikes/identify
npm install
cp .env.example .env        # add ANTHROPIC_API_KEY
npm run identify -- "https://www.tiktok.com/@user/video/123"
npm run identify -- "<link 1>" "<link 2>" "<link 3>"            # several at once
npm run identify -- "https://www.instagram.com/reel/abc/" --hint "Joe's Pizza Carmine St"
npm run identify -- "<link>" --json                             # full result as JSON
```

Pasting the whole share text works too ("Check this out! https://vm.tiktok.com/…").

Every run is appended to `runs/runs.jsonl` (gitignored), which you can use to fill in the `docs/platforms.md` matrix.

## What each platform gives

| Platform | Metadata used | Notes |
|---|---|---|
| TikTok | oEmbed: full caption, hashtags, author handle | No key needed. |
| YouTube | oEmbed: title, channel. With `YOUTUBE_API_KEY`: description, tags, recording location | The title alone is often too thin. |
| Instagram | Nothing (URL-only, by rule) | No hint: the app would ask "What place is this?". With `--hint`, the typed text stands in for the share extension's place field. |

Whether oEmbed responses may be used as extraction input is still an open M0 terms-check item.

## Provenance tags in the output

`[source]` read from the post · `[user]` from the hint · `[lookup]` from the map provider · `[estimated]` the model's guess, always shown with "(estimated)".

## Confidence → decision

The model's confidence is lowered when the map match is weak (×0.75) or missing (×0.6). At 0.8 or above with a solid map match, the place would pin automatically. Otherwise the app asks one question, or the save goes to "Needs a place". An entry with no location becomes an idea (no map pin).

## Place search

The plan's default is the Apple Maps Server API. It needs an Apple Developer account to create a Maps token, so until `APPLE_MAPS_AUTH_TOKEN` is set, searches go to OpenStreetMap Nominatim (free, no key, limited to 1 request per second). The Apple Maps code path hasn't been run yet.

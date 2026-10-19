// The decode pipeline shared by the local server and the CLI. Each stage reports progress
// through `emit` so the UI can show what was decoded as it happens.

import { appendFileSync, mkdirSync } from "node:fs";
import { mkdtemp, readFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fetchMetadata, type PostMetadata } from "./metadata.ts";
import { findPlace, providerName, type PlaceMatch, type PlaceSuggestion } from "./places.ts";
import { parseLink, type ParsedLink } from "./platform.ts";
import { understand, type EvidenceSource, type ExtractedExperience, type Provider, type UnderstandOutput } from "./understand.ts";
import { downloadVideo, extractFrames, readFrameText, toolStatus, transcribe, type FrameText, type Transcript, type VideoInfo } from "./video.ts";

export type StageName = "link" | "metadata" | "download" | "transcript" | "frames" | "understand" | "places";

export interface StageEvent {
  stage: StageName;
  status: "running" | "done" | "skipped" | "error";
  ms?: number;
  data?: unknown;
  note?: string;
}

/** How the "What place is this?" question went (event `question_answered` / `question_skipped`, ledger R7c). */
export interface QuestionOutcome {
  outcome: "picked" | "typed" | "skipped";
  /** From the question appearing to the answer or skip. */
  ms: number;
}

export interface DecodeOptions {
  hint: string | null;
  /** The autocomplete suggestion the user chose: its name and coordinates are a `user` hint (R13). */
  pickedPlace: PlaceSuggestion | null;
  question: QuestionOutcome | null;
  provider: Provider;
  analyzeVideo: boolean;
  sendFrames: boolean;
}

// Mirrors the Sourced<T> type planned for ExperienceCore.
type Provenance = "source" | "lookup" | "estimated" | "user";
export interface Sourced<T> {
  value: T;
  provenance: Provenance;
}

const AUTO_PIN_THRESHOLD = 0.8;
type Decision = "auto_pin" | "ask" | "needs_review" | "save_flexible" | "idea";

export interface DecodedExperience {
  title: Sourced<string>;
  intent: Sourced<string>;
  category: Sourced<string>;
  locationRequirement: Sourced<string>;
  place: {
    name: Sourced<string> | null;
    address: Sourced<string> | null;
    area: Sourced<string> | null;
    coordinates: Sourced<{ lat: number; lng: number }> | null;
    placeId: string | null;
    match: PlaceMatch | null;
    lookupSkipped: boolean;
    pickedByUser: boolean;
  } | null;
  candidates: string[];
  price: Sourced<string> | null;
  eventDates: Sourced<string> | null;
  isChain: boolean;
  evidence: string[];
  modelConfidence: number;
  confidence: number;
  userConfirmed: boolean;
  decision: Decision;
}

export interface DecodeResult {
  input: string;
  link: ParsedLink | null;
  metadata: PostMetadata | null;
  videoInfo: VideoInfo | null;
  transcript: Transcript | null;
  frameText: FrameText[];
  understanding: UnderstandOutput | null;
  experiences: DecodedExperience[];
  error: string | null;
  ms: number;
}

function provenanceOf(e: EvidenceSource): Provenance {
  return e === "user_hint" ? "user" : e === "inferred" ? "estimated" : "source";
}

function sourced<T>(value: T | null, provenance: Provenance): Sourced<T> | null {
  return value === null || value === "" ? null : { value, provenance };
}

function combine(e: ExtractedExperience, match: PlaceMatch | null, picked: PlaceSuggestion | null): DecodedExperience {
  const primary = e.places.find((p) => p.role === "primary") ?? e.places[0] ?? null;
  if (primary && picked) return withPickedPlace(combine(e, null, null), picked);
  const prov = primary ? provenanceOf(primary.evidence_source) : "estimated";
  const useLookup = match !== null && primary !== null && (match.nameMatch === "strong" || !primary.name);

  const factor = e.location_requirement === "none" ? 1 : useLookup ? 1 : match?.nameMatch === "weak" ? 0.75 : 0.6;
  const confidence = Math.round(e.confidence * factor * 100) / 100;

  let decision: Decision;
  if (e.location_requirement === "none") decision = "idea";
  else if (confidence >= AUTO_PIN_THRESHOLD && useLookup) decision = "auto_pin";
  else if (e.location_requirement === "flexible") decision = "save_flexible";
  else if (primary?.name) decision = "ask";
  else decision = "needs_review";

  const area = primary ? [primary.neighborhood, primary.city, primary.region, primary.country].filter(Boolean).join(", ") : "";
  return {
    // The user gives a place, never a title: a title built from the hint is the model's wording.
    title: { value: e.title, provenance: e.title_evidence === "user_hint" ? "estimated" : provenanceOf(e.title_evidence) },
    intent: { value: e.intent, provenance: "estimated" },
    category: { value: e.category, provenance: "estimated" },
    locationRequirement: { value: e.location_requirement, provenance: "estimated" },
    place: primary
      ? {
          name: sourced(primary.name, prov),
          address: useLookup ? sourced(match.address, "lookup") : sourced(primary.address, prov),
          area: sourced(area, prov),
          coordinates: useLookup ? { value: { lat: match.lat, lng: match.lng }, provenance: "lookup" } : null,
          placeId: useLookup ? match.placeId : null,
          match,
          lookupSkipped: primary.evidence_source === "inferred",
          pickedByUser: false,
        }
      : null,
    candidates: e.places.filter((p) => p !== primary).map((p) => [p.name, p.city].filter(Boolean).join(", ")),
    price: sourced(e.price_hint, provenanceOf(e.price_evidence)),
    eventDates: sourced(e.event_dates, "source"),
    isChain: e.is_chain,
    evidence: e.evidence,
    modelConfidence: e.confidence,
    confidence,
    userConfirmed: false,
    decision,
  };
}

/** The user chose this place in the question, so it is confirmed: no lookup, no guessing. */
function withPickedPlace(d: DecodedExperience, picked: PlaceSuggestion): DecodedExperience {
  return {
    ...d,
    locationRequirement: { value: "exact", provenance: "user" },
    place: {
      name: { value: picked.name, provenance: "user" },
      address: sourced(picked.subtitle, "user"),
      area: null,
      coordinates: { value: { lat: picked.lat, lng: picked.lng }, provenance: "user" },
      placeId: picked.placeId,
      match: null,
      lookupSkipped: false,
      pickedByUser: true,
    },
    confidence: d.modelConfidence,
    userConfirmed: true,
    decision: "auto_pin",
  };
}

export async function decode(input: string, opts: DecodeOptions, emit: (e: StageEvent) => void): Promise<DecodeResult> {
  const started = Date.now();
  const result: DecodeResult = {
    input,
    link: null,
    metadata: null,
    videoInfo: null,
    transcript: null,
    frameText: [],
    understanding: null,
    experiences: [],
    error: null,
    ms: 0,
  };

  async function stage<T>(name: StageName, fn: () => Promise<T>, view?: (v: T) => unknown): Promise<T | null> {
    const t0 = Date.now();
    emit({ stage: name, status: "running" });
    try {
      const value = await fn();
      emit({ stage: name, status: "done", ms: Date.now() - t0, data: view ? view(value) : value });
      return value;
    } catch (err) {
      emit({ stage: name, status: "error", ms: Date.now() - t0, note: err instanceof Error ? err.message : String(err) });
      return null;
    }
  }
  const skip = (name: StageName, note: string) => emit({ stage: name, status: "skipped", note });

  const tmp = await mkdtemp(join(tmpdir(), "experience-decode-"));
  try {
    result.link = await stage("link", () => parseLink(input));
    if (!result.link) {
      result.error = "Couldn't read that link.";
      return result;
    }
    const link = result.link;
    result.metadata = await stage("metadata", () => fetchMetadata(link));

    // Local video analysis: TikTok/YouTube only. Instagram stays URL-only (CLAUDE.md).
    let frames: { atSec: number; jpegBase64: string }[] = [];
    const videoSkip =
      link.platform === "instagram" ? "Instagram is URL-only: the video is never fetched."
      : !opts.analyzeVideo ? "Video analysis is turned off."
      : null;
    const tools = await toolStatus();
    if (videoSkip) {
      for (const s of ["download", "transcript", "frames"] as const) skip(s, videoSkip);
    } else if (!tools.ytdlp || !tools.ffmpeg) {
      for (const s of ["download", "transcript", "frames"] as const) skip(s, "Needs yt-dlp and ffmpeg: run `npm run setup`.");
    } else {
      const video = await stage("download", () => downloadVideo(link.resolvedUrl, tmp), (v) => v.info);
      if (video) {
        result.videoInfo = video.info;
        const [transcript, frameData] = await Promise.all([
          tools.whisper && tools.whisperModel
            ? stage("transcript", () => transcribe(video.file, tmp))
            : (skip("transcript", "Needs whisper-cpp and its model: run `npm run setup`."), Promise.resolve(null)),
          stage(
            "frames",
            async () => {
              const extracted = await extractFrames(video.file, tmp, video.info.durationSec);
              const text = await readFrameText(extracted).catch(() => extracted.map((f) => ({ atSec: f.atSec, lines: [] })));
              const images = await Promise.all(extracted.map(async (f) => ({ atSec: f.atSec, jpegBase64: (await readFile(f.path)).toString("base64") })));
              return { text, images };
            },
            (v) => v.images.map((img, i) => ({ ...img, lines: v.text[i]?.lines ?? [] })),
          ),
        ]);
        result.transcript = transcript;
        result.frameText = frameData?.text ?? [];
        frames = frameData?.images ?? [];
      } else {
        skip("transcript", "No video to listen to.");
        skip("frames", "No video to look at.");
      }
    }

    const meta = result.metadata;
    const postSignals = !!(meta?.caption || meta?.title || result.videoInfo?.description || result.transcript?.text || result.frameText.some((f) => f.lines.length));
    if (!meta || !(postSignals || opts.hint || opts.pickedPlace)) {
      const why = opts.question?.outcome === "skipped"
        ? "Question skipped and nothing to read: this save goes to “Needs a place”."
        : "Nothing to read. The app would ask “What place is this?”";
      skip("understand", why);
      skip("places", why);
      return result;
    }

    result.understanding = await stage("understand", () =>
      understand(
        {
          platform: link.platform,
          url: link.resolvedUrl,
          metadata: meta,
          videoInfo: result.videoInfo,
          transcript: result.transcript,
          frameText: result.frameText,
          frames: opts.sendFrames ? frames : [],
          hint: opts.pickedPlace ? [opts.pickedPlace.name, opts.pickedPlace.subtitle].filter(Boolean).join(", ") : opts.hint,
        },
        opts.provider,
      ),
    );
    if (!result.understanding) {
      skip("places", "Understanding failed.");
      return result;
    }

    const extracted = result.understanding.result.experiences;
    result.experiences =
      (await stage(
        "places",
        async () => {
          const out: DecodedExperience[] = [];
          for (const e of extracted) {
            const primary = e.places.find((p) => p.role === "primary") ?? e.places[0];
            // The picked place answers for the place the hint describes. With nothing else to read, that's every place.
            const picked = opts.pickedPlace && primary && (primary.evidence_source === "user_hint" || !postSignals) ? opts.pickedPlace : null;
            if (picked) {
              out.push(combine(e, null, picked));
              continue;
            }
            // Don't give a guessed place a real address: only look up names read from the post or the hint.
            const lookUp = primary && e.location_requirement !== "none" && primary.evidence_source !== "inferred";
            const match = lookUp ? await findPlace(primary) : null;
            out.push(combine(e, match, null));
          }
          return out;
        },
        (v) => ({ provider: providerName(), experiences: v }),
      )) ?? [];
    return result;
  } finally {
    await rm(tmp, { recursive: true, force: true }); // ADR-008: nothing from the video outlives the run
    result.ms = Date.now() - started;
    mkdirSync(new URL("./runs/", import.meta.url), { recursive: true });
    appendFileSync(new URL("./runs/runs.jsonl", import.meta.url), JSON.stringify({ at: new Date().toISOString(), options: { ...opts }, ...result }) + "\n");
  }
}

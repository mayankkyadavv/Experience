// Phase 0 identification spike.
//
//   npm run identify -- <link or shared text> [more links...] [--hint "Joe's Pizza NYC"] [--json]
//
// Pipeline: link -> platform + short-link resolution -> public metadata -> Claude extraction
// -> place search -> Experience-shaped result with provenance on every field.
// Each run is appended to runs/runs.jsonl (gitignored) to fill the docs/platforms.md matrix.

import { appendFileSync, mkdirSync } from "node:fs";
import { parseArgs } from "node:util";
import Anthropic from "@anthropic-ai/sdk";
import { extractPlaces, MODEL, type ExtractedPlace } from "./extract.ts";
import { fetchMetadata, type PostMetadata } from "./metadata.ts";
import { findPlace, providerName, type PlaceMatch } from "./places.ts";
import { parseLink, UnsupportedLinkError, type ParsedLink } from "./platform.ts";

// Mirrors the Sourced<T> type planned for ExperienceCore.
type Provenance = "source" | "lookup" | "estimated" | "user";
interface Sourced<T> {
  value: T;
  provenance: Provenance;
}

const AUTO_PIN_THRESHOLD = 0.8; // design doc default, tune from the eval

type Decision = "auto_pin" | "ask" | "needs_review" | "idea";

interface IdentifiedPlace {
  title: Sourced<string> | null;
  kind: ExtractedPlace["kind"];
  category: Sourced<string>;
  businessType: Sourced<string> | null;
  location: {
    address: Sourced<string> | null;
    neighborhood: Sourced<string> | null;
    city: Sourced<string> | null;
    region: Sourced<string> | null;
    country: Sourced<string> | null;
    coordinates: Sourced<{ lat: number; lng: number }> | null;
    placeId: string | null;
  };
  fields: {
    price: Sourced<string> | null;
    eventDates: Sourced<string> | null;
  };
  isChain: boolean;
  evidence: string[];
  match: PlaceMatch | null;
  modelConfidence: number;
  confidence: number;
  decision: Decision;
}

interface RunResult {
  input: string;
  link: ParsedLink;
  metadata: PostMetadata;
  hint: string | null;
  places: IdentifiedPlace[];
  question: string | null;
  reasoning: string | null;
  usage: { input_tokens: number; output_tokens: number } | null;
  ms: number;
}

function fromEvidence(e: "post" | "user_hint" | "inferred" | "none"): Provenance {
  return e === "post" ? "source" : e === "user_hint" ? "user" : "estimated";
}

function sourced<T>(value: T | null, provenance: Provenance): Sourced<T> | null {
  return value === null || value === "" ? null : { value, provenance };
}

function combine(p: ExtractedPlace, match: PlaceMatch | null): IdentifiedPlace {
  const locProv = fromEvidence(p.location_evidence);
  const useLookup = match !== null && (match.nameMatch === "strong" || !p.name);

  // A weak or missing map match makes the model's confidence less trustworthy.
  const factor = p.kind === "idea" ? 1 : useLookup ? 1 : match?.nameMatch === "weak" ? 0.75 : 0.6;
  const confidence = Math.round(p.confidence * factor * 100) / 100;

  let decision: Decision;
  if (p.kind === "idea") decision = "idea";
  else if (confidence >= AUTO_PIN_THRESHOLD && useLookup) decision = "auto_pin";
  else if (p.name) decision = "ask";
  else decision = "needs_review";

  return {
    title: sourced(p.name, fromEvidence(p.name_evidence)),
    kind: p.kind,
    category: { value: p.category, provenance: "estimated" },
    businessType: sourced(p.business_type, "estimated"),
    location: {
      address: useLookup ? sourced(match.address, "lookup") : sourced(p.address, locProv),
      neighborhood: sourced(p.neighborhood, locProv),
      city: sourced(p.city, locProv),
      region: sourced(p.region, locProv),
      country: sourced(p.country, locProv),
      coordinates: useLookup ? { value: { lat: match.lat, lng: match.lng }, provenance: "lookup" } : null,
      placeId: useLookup ? match.placeId : null,
    },
    fields: {
      price: sourced(p.price_hint, fromEvidence(p.price_evidence)),
      eventDates: sourced(p.event_dates, "source"),
    },
    isChain: p.is_chain,
    evidence: p.evidence,
    match,
    modelConfidence: p.confidence,
    confidence,
    decision,
  };
}

async function identify(input: string, hint: string | null): Promise<RunResult> {
  const started = Date.now();
  const link = await parseLink(input);
  const metadata = await fetchMetadata(link);
  const base = { input, link, metadata, hint };

  const hasText = metadata.caption || metadata.title || metadata.geotag;
  if (!hasText && !hint) {
    // Nothing to extract from (Instagram, or a private/deleted post): the app asks the user.
    return { ...base, places: [], question: "What place is this?", reasoning: null, usage: null, ms: Date.now() - started };
  }

  const { result, usage } = await extractPlaces(link.platform, link.resolvedUrl, metadata, hint);
  const places: IdentifiedPlace[] = [];
  for (const p of result.places) places.push(combine(p, await findPlace(p)));

  const question = result.clarifying_question ?? (places.some((p) => p.decision === "ask") ? `Is this ${places[0].title?.value}?` : null);
  return {
    ...base,
    places,
    question: places.every((p) => p.decision === "auto_pin" || p.decision === "idea") ? null : question,
    reasoning: result.reasoning,
    usage: { input_tokens: usage.input_tokens, output_tokens: usage.output_tokens },
    ms: Date.now() - started,
  };
}

// --- Output ------------------------------------------------------------------------------

const tty = process.stdout.isTTY;
const dim = (s: string) => (tty ? `\x1b[2m${s}\x1b[0m` : s);
const bold = (s: string) => (tty ? `\x1b[1m${s}\x1b[0m` : s);

/** Same rule as SourcedText in the app: estimates are always labeled. */
function show(f: Sourced<string> | null): string {
  if (!f) return dim("—");
  const label = f.provenance === "estimated" ? " (estimated)" : "";
  return `${f.value}${label} ${dim(`[${f.provenance}]`)}`;
}

const DECISION_TEXT: Record<Decision, string> = {
  auto_pin: "pin on map automatically",
  ask: "ask the user to confirm",
  needs_review: "goes to “Needs a place”",
  idea: "save as an idea (no map pin)",
};

function print(r: RunResult) {
  const m = r.metadata;
  console.log(`\n${bold(r.link.platform.toUpperCase())}  ${r.link.resolvedUrl}`);
  if (r.link.resolvedUrl !== r.link.originalUrl) console.log(dim(`  short link: ${r.link.originalUrl}`));
  console.log(dim(`  metadata from: ${m.sources.join(", ") || "nothing (URL only)"}`));
  if (m.author) console.log(`  author: ${m.author}`);
  if (m.title && m.title !== m.caption) console.log(`  title: ${m.title}`);
  if (m.caption) console.log(`  caption: ${m.caption.length > 300 ? m.caption.slice(0, 300) + "…" : m.caption}`);
  if (m.geotag) console.log(`  geotag: ${m.geotag.lat}, ${m.geotag.lng} ${m.geotag.label ?? ""}`);
  if (r.hint) console.log(`  user hint: ${r.hint}`);
  for (const n of m.notes) console.log(dim(`  note: ${n}`));

  if (r.places.length === 0) {
    console.log(`\n  No place identified.${r.question ? ` Would ask: “${r.question}”` : ""}`);
  }
  r.places.forEach((p, i) => {
    const loc = p.location;
    console.log(`\n  ${bold(`${i + 1}. ${p.title?.value ?? "(no specific venue)"}`)} ${p.title ? dim(`[${p.title.provenance}]`) : ""}`);
    console.log(`     kind:        ${p.kind}${p.isChain ? " · chain (multiple locations)" : ""}`);
    console.log(`     category:    ${show(p.category)}`);
    console.log(`     type:        ${show(p.businessType)}`);
    console.log(`     address:     ${show(loc.address)}`);
    console.log(`     area:        ${[loc.neighborhood, loc.city, loc.region, loc.country].filter(Boolean).map(show).join(", ") || dim("—")}`);
    console.log(`     coordinates: ${loc.coordinates ? `${loc.coordinates.value.lat.toFixed(5)}, ${loc.coordinates.value.lng.toFixed(5)} ${dim("[lookup]")}` : dim("—")}`);
    if (loc.placeId) console.log(`     place id:    ${loc.placeId}`);
    if (p.fields.price) console.log(`     price:       ${show(p.fields.price)}`);
    if (p.fields.eventDates) console.log(`     dates:       ${show(p.fields.eventDates)}`);
    if (p.match) console.log(dim(`     map match:   ${p.match.provider} “${p.match.name ?? "?"}” (${p.match.nameMatch}) via “${p.match.query}”`));
    else if (p.kind !== "idea") console.log(dim(`     map match:   none from ${providerName()}`));
    if (p.evidence.length) console.log(dim(`     evidence:    ${p.evidence.map((e) => `“${e}”`).join("  ")}`));
    console.log(`     confidence:  ${p.confidence.toFixed(2)}${p.confidence !== p.modelConfidence ? dim(` (model said ${p.modelConfidence.toFixed(2)})`) : ""} → ${DECISION_TEXT[p.decision]}`);
  });
  if (r.question && r.places.length > 0) console.log(`\n  Would ask: “${r.question}”`);
  if (r.reasoning) console.log(dim(`\n  ${r.reasoning}`));
  console.log(dim(`  ${(r.ms / 1000).toFixed(1)}s${r.usage ? ` · ${MODEL} · ${r.usage.input_tokens} in / ${r.usage.output_tokens} out tokens` : ""}`));
}

// --- Main --------------------------------------------------------------------------------

const { values, positionals } = parseArgs({
  allowPositionals: true,
  options: { hint: { type: "string" }, json: { type: "boolean", default: false } },
});

if (positionals.length === 0) {
  console.error('Usage: npm run identify -- <link or shared text> [more links...] [--hint "place name"] [--json]');
  process.exit(1);
}

mkdirSync(new URL("./runs/", import.meta.url), { recursive: true });
const log = new URL("./runs/runs.jsonl", import.meta.url);

let failed = 0;
for (const input of positionals) {
  try {
    const result = await identify(input, values.hint ?? null);
    appendFileSync(log, JSON.stringify({ at: new Date().toISOString(), ...result }) + "\n");
    if (values.json) console.log(JSON.stringify(result, null, 2));
    else print(result);
  } catch (err) {
    failed++;
    if (err instanceof UnsupportedLinkError) console.error(`\n${input}\n  ${err.message}`);
    else if (err instanceof Anthropic.AuthenticationError) {
      console.error("\nClaude API key missing or invalid. Put ANTHROPIC_API_KEY in spikes/identify/.env (see .env.example).");
      process.exit(1);
    } else if (err instanceof Anthropic.APIError) console.error(`\n${input}\n  Claude API error ${err.status}: ${err.message}`);
    else console.error(`\n${input}\n  ${err instanceof Error ? err.message : String(err)}`);
  }
}
process.exitCode = failed > 0 ? 1 : 0;

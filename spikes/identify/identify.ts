// Command-line version of the local decoder (same pipeline as `npm run serve`).
//
//   npm run identify -- <link> [more links...] [--hint "Joe's Pizza NYC"] [--model gemma3:12b|claude] [--no-video] [--no-frames] [--json]

import { parseArgs } from "node:util";
import { decode, type DecodedExperience, type Sourced } from "./pipeline.ts";
import { listOllamaModels, type Provider } from "./understand.ts";

const { values, positionals } = parseArgs({
  allowPositionals: true,
  options: {
    hint: { type: "string" },
    model: { type: "string" },
    "no-video": { type: "boolean", default: false },
    "no-frames": { type: "boolean", default: false },
    json: { type: "boolean", default: false },
  },
});

if (positionals.length === 0) {
  console.error('Usage: npm run identify -- <link> [more links...] [--hint "place"] [--model <ollama model>|claude] [--no-video] [--no-frames] [--json]');
  process.exit(1);
}

async function pickProvider(): Promise<Provider> {
  if (values.model === "claude") return { kind: "claude" };
  if (values.model) return { kind: "ollama", model: values.model };
  const models = await listOllamaModels();
  const local = models?.find((m) => m.vision) ?? models?.[0];
  return local ? { kind: "ollama", model: local.name } : { kind: "claude" };
}

const show = (f: Sourced<string> | null) => (f ? `${f.value}${f.provenance === "estimated" ? " (estimated)" : ""} [${f.provenance}]` : "—");

function printExperience(e: DecodedExperience, i: number) {
  console.log(`\n  ${i + 1}. ${e.title.value} [${e.title.provenance}]`);
  console.log(`     intent:      ${show(e.intent)}`);
  console.log(`     category:    ${show(e.category)} · location ${e.locationRequirement.value}`);
  if (e.place) {
    console.log(`     place:       ${show(e.place.name)}`);
    console.log(`     address:     ${show(e.place.address)}`);
    if (e.place.coordinates) console.log(`     coordinates: ${e.place.coordinates.value.lat.toFixed(5)}, ${e.place.coordinates.value.lng.toFixed(5)} [${e.place.coordinates.provenance}]`);
  }
  if (e.candidates.length) console.log(`     alternatives: ${e.candidates.join(" · ")}`);
  console.log(`     confidence:  ${e.confidence.toFixed(2)} → ${e.decision}`);
}

const provider = await pickProvider();
let failed = 0;
for (const input of positionals) {
  console.log(`\n${input}  (${provider.kind === "claude" ? "Claude" : `local ${provider.model}`})`);
  const result = await decode(
    input,
    { hint: values.hint ?? null, pickedPlace: null, question: null, provider, analyzeVideo: !values["no-video"], sendFrames: !values["no-frames"] },
    (e) => {
      if (e.status === "running") return;
      const time = e.ms !== undefined ? ` ${(e.ms / 1000).toFixed(1)}s` : "";
      console.log(`  ${e.status.padEnd(7)} ${e.stage}${time}${e.note ? `: ${e.note}` : ""}`);
    },
  );
  if (values.json) console.log(JSON.stringify(result, null, 2));
  else {
    if (result.understanding) console.log(`\n  ${result.understanding.result.summary}`);
    result.experiences.forEach(printExperience);
    if (result.understanding?.result.clarifying_question) console.log(`\n  Would ask: “${result.understanding.result.clarifying_question}”`);
  }
  if (result.error || !result.understanding) failed++;
}
process.exitCode = failed > 0 ? 1 : 0;

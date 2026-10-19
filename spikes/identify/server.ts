// Local decode service. Binds to 127.0.0.1 only.
//
//   npm run serve   →   http://localhost:4321
//
// GET /api/status            tools, models and keys available on this Mac
// GET /api/suggest?q=...     place autocomplete for "What place is this?" (optional near=lat,lng)
// GET /api/decode?url=...    Server-Sent Events, one per pipeline stage, then "end"

import { readFile } from "node:fs/promises";
import { createServer, type ServerResponse } from "node:http";
import { decode, type QuestionOutcome, type StageEvent } from "./pipeline.ts";
import { providerName, suggestPlaces, type PlaceSuggestion } from "./places.ts";
import { claudeAvailable, CLAUDE_MODEL, listOllamaModels, type Provider } from "./understand.ts";
import { toolStatus } from "./video.ts";

const PORT = Number(process.env.PORT ?? 4321);
const PAGE = new URL("./public/index.html", import.meta.url);

function json(res: ServerResponse, status: number, body: unknown) {
  res.writeHead(status, { "content-type": "application/json" });
  res.end(JSON.stringify(body));
}

let busy = false;

function parseJson<T>(raw: string | null): T | null {
  if (!raw) return null;
  try {
    return JSON.parse(raw) as T;
  } catch {
    return null;
  }
}

function parseNear(raw: string | null): { lat: number; lng: number } | null {
  const [lat, lng] = (raw ?? "").split(",").map(Number);
  return Number.isFinite(lat) && Number.isFinite(lng) && raw ? { lat, lng } : null;
}

const server = createServer(async (req, res) => {
  const url = new URL(req.url ?? "/", `http://${req.headers.host}`);

  if (req.method === "GET" && url.pathname === "/") {
    res.writeHead(200, { "content-type": "text/html; charset=utf-8" });
    res.end(await readFile(PAGE));
    return;
  }

  if (req.method === "GET" && url.pathname === "/api/status") {
    const [tools, ollama] = await Promise.all([toolStatus(), listOllamaModels()]);
    json(res, 200, { tools, ollama, claude: { available: claudeAvailable(), model: CLAUDE_MODEL }, places: providerName() });
    return;
  }

  if (req.method === "GET" && url.pathname === "/api/suggest") {
    const q = url.searchParams.get("q")?.trim() ?? "";
    if (q.length < 2) return json(res, 200, { suggestions: [] });
    try {
      json(res, 200, { suggestions: await suggestPlaces(q, parseNear(url.searchParams.get("near"))) });
    } catch (err) {
      json(res, 502, { error: err instanceof Error ? err.message : String(err) });
    }
    return;
  }

  if (req.method === "GET" && url.pathname === "/api/decode") {
    const input = url.searchParams.get("url")?.trim();
    if (!input) return json(res, 400, { error: "Missing url" });
    if (busy) return json(res, 409, { error: "A decode is already running." });

    const model = url.searchParams.get("model") ?? "claude";
    const provider: Provider = model === "claude" ? { kind: "claude" } : { kind: "ollama", model };

    res.writeHead(200, { "content-type": "text/event-stream", "cache-control": "no-cache", connection: "keep-alive" });
    const send = (event: string, data: unknown) => res.write(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`);

    busy = true;
    try {
      const result = await decode(
        input,
        {
          hint: url.searchParams.get("hint")?.trim() || null,
          pickedPlace: parseJson<PlaceSuggestion>(url.searchParams.get("place")),
          question: parseJson<QuestionOutcome>(url.searchParams.get("question")),
          provider,
          analyzeVideo: url.searchParams.get("video") !== "0",
          sendFrames: url.searchParams.get("frames") !== "0",
        },
        (e: StageEvent) => send("stage", e),
      );
      send("end", { ms: result.ms, error: result.error });
    } catch (err) {
      send("end", { error: err instanceof Error ? err.message : String(err) });
    } finally {
      busy = false;
      res.end();
    }
    return;
  }

  json(res, 404, { error: "Not found" });
});

server.on("error", (err: NodeJS.ErrnoException) => {
  if (err.code !== "EADDRINUSE") throw err;
  console.error(`Port ${PORT} is already in use: the decoder is probably already running at http://localhost:${PORT}.`);
  console.error(`To restart it, stop the other one first: kill $(lsof -ti tcp:${PORT})`);
  process.exit(1);
});

server.listen(PORT, "127.0.0.1", () => {
  console.log(`Experience decoder → http://localhost:${PORT}`);
});

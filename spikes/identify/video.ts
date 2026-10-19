// Local video analysis (ADR-008 research exception): temporary download, speech-to-text,
// frames and on-screen text. Runs only on this Mac; every file lives in a temp dir that the
// pipeline deletes at the end of each run. TikTok/YouTube only; Instagram stays URL-only.

import { spawn } from "node:child_process";
import { existsSync, statSync } from "node:fs";
import { readdir, readFile } from "node:fs/promises";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

const HERE = fileURLToPath(new URL(".", import.meta.url));
export const WHISPER_MODEL = process.env.WHISPER_MODEL ?? join(HERE, "models", "ggml-large-v3-turbo.bin");

export interface VideoInfo {
  title: string | null;
  description: string | null;
  uploader: string | null;
  channel: string | null;
  durationSec: number | null;
  tags: string[];
  categories: string[];
  location: string | null;
  music: string | null;
  uploadDate: string | null;
  viewCount: number | null;
}

export interface TranscriptSegment {
  fromMs: number;
  toMs: number;
  text: string;
}

export interface Transcript {
  language: string | null;
  segments: TranscriptSegment[];
  text: string;
}

export interface Frame {
  atSec: number;
  path: string;
}

export interface FrameText {
  atSec: number;
  lines: { text: string; confidence: number }[];
}

// --- Process helpers ---------------------------------------------------------------------

export async function run(
  cmd: string,
  args: string[],
  timeoutMs = 120_000,
): Promise<{ stdout: string; stderr: string }> {
  return new Promise((resolve, reject) => {
    const child = spawn(cmd, args, { stdio: ["ignore", "pipe", "pipe"] });
    let stdout = "";
    let stderr = "";
    const timer = setTimeout(() => {
      child.kill("SIGKILL");
      reject(new Error(`${cmd} timed out after ${Math.round(timeoutMs / 1000)}s`));
    }, timeoutMs);
    child.stdout.on("data", (d) => (stdout += d));
    child.stderr.on("data", (d) => (stderr += d));
    child.on("error", (err) => {
      clearTimeout(timer);
      reject(err);
    });
    child.on("close", (code) => {
      clearTimeout(timer);
      if (code === 0) resolve({ stdout, stderr });
      else reject(new Error(`${cmd} exited ${code}: ${stderr.trim().split("\n").slice(-3).join(" ")}`));
    });
  });
}

async function has(cmd: string): Promise<boolean> {
  try {
    await run("/bin/sh", ["-c", `command -v ${cmd}`], 5000);
    return true;
  } catch {
    return false;
  }
}

export async function toolStatus() {
  const [ytdlp, ffmpeg, whisper] = await Promise.all([has("yt-dlp"), has("ffmpeg"), has("whisper-cli")]);
  return { ytdlp, ffmpeg, whisper, whisperModel: existsSync(WHISPER_MODEL), ocr: await has("swiftc") };
}

// --- Download ----------------------------------------------------------------------------

export async function downloadVideo(url: string, dir: string): Promise<{ file: string; info: VideoInfo }> {
  await run(
    "yt-dlp",
    [
      "--no-playlist",
      "--no-warnings",
      "--quiet",
      "-f", "bv*[height<=720]+ba/b[height<=720]/b",
      "--merge-output-format", "mp4",
      "--max-filesize", "300M",
      "--write-info-json",
      "-o", join(dir, "video.%(ext)s"),
      url,
    ],
    180_000,
  );
  const files = await readdir(dir);
  const video = files.find((f) => f.startsWith("video.") && !f.endsWith(".json"));
  if (!video) throw new Error("yt-dlp finished but no video file was written (photo post or unavailable).");
  const infoFile = files.find((f) => f.endsWith(".info.json"));
  const raw: any = infoFile ? JSON.parse(await readFile(join(dir, infoFile), "utf8")) : {};
  const music = raw.track ? [raw.track, raw.artist].filter(Boolean).join(" · ") : null;
  return {
    file: join(dir, video),
    info: {
      title: raw.title ?? null,
      description: raw.description || null,
      uploader: raw.uploader ?? raw.uploader_id ?? null,
      channel: raw.channel ?? null,
      durationSec: typeof raw.duration === "number" ? raw.duration : null,
      tags: raw.tags ?? [],
      categories: raw.categories ?? [],
      location: raw.location ?? null,
      music,
      uploadDate: raw.upload_date ?? null,
      viewCount: raw.view_count ?? null,
    },
  };
}

async function probeDuration(file: string): Promise<number> {
  const { stdout } = await run("ffprobe", ["-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", file], 15_000);
  return Number(stdout.trim()) || 0;
}

// --- Frames ------------------------------------------------------------------------------

export async function extractFrames(file: string, dir: string, durationSec: number | null, count = 8): Promise<Frame[]> {
  const duration = durationSec && durationSec > 0 ? durationSec : await probeDuration(file);
  const n = duration < 4 ? 2 : count;
  const frames: Frame[] = Array.from({ length: n }, (_, i) => ({
    atSec: Math.round(((duration * (i + 0.5)) / n) * 10) / 10,
    path: join(dir, `frame_${String(i).padStart(2, "0")}.jpg`),
  }));
  await Promise.all(
    frames.map((f) =>
      run("ffmpeg", ["-v", "error", "-ss", String(f.atSec), "-i", file, "-frames:v", "1", "-vf", "scale='min(768,iw)':-2", "-q:v", "4", "-y", f.path], 30_000),
    ),
  );
  return frames.filter((f) => existsSync(f.path));
}

// --- Speech to text (whisper.cpp, Metal) -------------------------------------------------

function parseStamp(s: string): number {
  // "00:01:02,345"
  const [hms, ms] = s.split(",");
  const [h, m, sec] = hms.split(":").map(Number);
  return ((h * 60 + m) * 60 + sec) * 1000 + Number(ms);
}

export async function transcribe(file: string, dir: string): Promise<Transcript> {
  const wav = join(dir, "audio.wav");
  try {
    await run("ffmpeg", ["-v", "error", "-i", file, "-vn", "-ar", "16000", "-ac", "1", "-c:a", "pcm_s16le", "-y", wav], 60_000);
  } catch {
    return { language: null, segments: [], text: "" }; // no audio stream
  }
  const out = join(dir, "transcript");
  await run("whisper-cli", ["-m", WHISPER_MODEL, "-f", wav, "-l", "auto", "-oj", "-of", out, "-np"], 300_000);
  const raw: any = JSON.parse(await readFile(`${out}.json`, "utf8"));
  const segments: TranscriptSegment[] = (raw.transcription ?? [])
    .map((s: any) => ({ fromMs: parseStamp(s.timestamps.from), toMs: parseStamp(s.timestamps.to), text: String(s.text).trim() }))
    .filter((s: TranscriptSegment) => s.text.length > 0);
  return { language: raw.result?.language ?? null, segments, text: segments.map((s) => s.text).join(" ") };
}

// --- On-screen text (Apple Vision) -------------------------------------------------------

const OCR_SRC = join(HERE, "ocr.swift");
const OCR_BIN = join(HERE, "build", "ocr");

async function ensureOcrBinary(): Promise<void> {
  if (existsSync(OCR_BIN) && statSync(OCR_BIN).mtimeMs >= statSync(OCR_SRC).mtimeMs) return;
  await run("/bin/mkdir", ["-p", join(HERE, "build")]);
  await run("swiftc", ["-O", OCR_SRC, "-o", OCR_BIN], 180_000);
}

export async function readFrameText(frames: Frame[]): Promise<FrameText[]> {
  if (frames.length === 0) return [];
  await ensureOcrBinary();
  const { stdout } = await run(OCR_BIN, frames.map((f) => f.path), 60_000);
  const results: { file: string; lines: { text: string; confidence: number }[] }[] = JSON.parse(stdout);
  return frames.map((f) => ({
    atSec: f.atSec,
    lines: (results.find((r) => r.file === f.path)?.lines ?? []).filter((l) => l.confidence >= 0.3),
  }));
}

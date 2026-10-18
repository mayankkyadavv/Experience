// Fetches only what each platform's official, public endpoints return for a post.
// Never downloads or stores the video itself.
//
// Open M0 terms-check item: whether oEmbed responses may be used as extraction input
// (not just for embedding). This spike uses TikTok/YouTube oEmbed to measure what it buys us;
// Instagram is URL-only until confirmed.

import type { ParsedLink } from "./platform.ts";

export interface PostMetadata {
  /** Which endpoints answered, e.g. ["tiktok_oembed"]. Empty means URL-only. */
  sources: string[];
  title: string | null;
  /** Full caption/description where the platform exposes it (TikTok's oEmbed title is the caption). */
  caption: string | null;
  author: string | null;
  authorUrl: string | null;
  tags: string[];
  /** Geotag the creator attached, if the platform exposes one. */
  geotag: { lat: number; lng: number; label: string | null } | null;
  /** Kept for the feed card later; not used for extraction. */
  thumbnailUrl: string | null;
  unavailable: boolean;
  notes: string[];
}

function empty(): PostMetadata {
  return {
    sources: [],
    title: null,
    caption: null,
    author: null,
    authorUrl: null,
    tags: [],
    geotag: null,
    thumbnailUrl: null,
    unavailable: false,
    notes: [],
  };
}

async function getJson(url: string): Promise<{ status: number; body: any }> {
  const res = await fetch(url, { signal: AbortSignal.timeout(10000) });
  const body = res.ok ? await res.json() : null;
  return { status: res.status, body };
}

async function tiktok(link: ParsedLink): Promise<PostMetadata> {
  const meta = empty();
  const { status, body } = await getJson(
    `https://www.tiktok.com/oembed?url=${encodeURIComponent(link.resolvedUrl)}`,
  );
  if (!body) {
    meta.unavailable = status === 400 || status === 404;
    meta.notes.push(`TikTok oEmbed returned HTTP ${status} (private, deleted, or region-blocked).`);
    return meta;
  }
  meta.sources.push("tiktok_oembed");
  meta.caption = body.title || null;
  meta.author = body.author_unique_id ? `@${body.author_unique_id}` : (body.author_name ?? null);
  meta.authorUrl = body.author_url ?? null;
  meta.thumbnailUrl = body.thumbnail_url ?? null;
  meta.tags = (meta.caption?.match(/#[\p{L}\p{N}_]+/gu) ?? []).map((t) => t.slice(1));
  return meta;
}

async function youtube(link: ParsedLink): Promise<PostMetadata> {
  const meta = empty();
  const watchUrl = link.postId ? `https://www.youtube.com/watch?v=${link.postId}` : link.resolvedUrl;
  const { status, body } = await getJson(
    `https://www.youtube.com/oembed?format=json&url=${encodeURIComponent(watchUrl)}`,
  );
  if (body) {
    meta.sources.push("youtube_oembed");
    meta.title = body.title ?? null;
    meta.author = body.author_name ?? null;
    meta.authorUrl = body.author_url ?? null;
    meta.thumbnailUrl = body.thumbnail_url ?? null;
  } else {
    meta.unavailable = status === 401 || status === 403 || status === 404;
    meta.notes.push(`YouTube oEmbed returned HTTP ${status} (private or deleted).`);
  }

  // The Data API adds the description, tags and (rarely) a recording location. Optional.
  const key = process.env.YOUTUBE_API_KEY;
  if (!key) {
    meta.notes.push("No YOUTUBE_API_KEY: description and tags not fetched (title only).");
    return meta;
  }
  if (!link.postId) return meta;
  const api = await getJson(
    `https://www.googleapis.com/youtube/v3/videos?part=snippet,recordingDetails&id=${link.postId}&key=${key}`,
  );
  const item = api.body?.items?.[0];
  if (!item) {
    meta.notes.push(`YouTube Data API returned no item (HTTP ${api.status}).`);
    return meta;
  }
  meta.sources.push("youtube_data_api");
  meta.title ??= item.snippet?.title ?? null;
  meta.author ??= item.snippet?.channelTitle ?? null;
  meta.caption = item.snippet?.description || null;
  meta.tags = item.snippet?.tags ?? [];
  const loc = item.recordingDetails?.location;
  if (loc?.latitude != null && loc?.longitude != null) {
    meta.geotag = {
      lat: loc.latitude,
      lng: loc.longitude,
      label: item.recordingDetails?.locationDescription ?? null,
    };
  }
  meta.unavailable = false;
  return meta;
}

export async function fetchMetadata(link: ParsedLink): Promise<PostMetadata> {
  switch (link.platform) {
    case "tiktok":
      return tiktok(link);
    case "youtube":
      return youtube(link);
    case "instagram": {
      const meta = empty();
      meta.notes.push("Instagram is URL-only: no caption, author or geotag is fetched.");
      return meta;
    }
  }
}

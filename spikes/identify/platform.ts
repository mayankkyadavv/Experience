// Platform detection, URL extraction from share payloads, and short-link resolution.

export type Platform = "instagram" | "tiktok" | "youtube";

export interface ParsedLink {
  platform: Platform;
  originalUrl: string;
  /** URL after following redirects (short links). Instagram is never fetched, so this equals originalUrl. */
  resolvedUrl: string;
  /** Platform's own id for the post, when it can be read from the URL. */
  postId: string | null;
}

export class UnsupportedLinkError extends Error {}

/** Share extensions sometimes get "Check this out! https://vm.tiktok.com/abc/" instead of a bare URL. */
export function firstUrl(text: string): string | null {
  const match = text.match(/https?:\/\/[^\s<>"']+/i);
  return match ? match[0].replace(/[).,!?]+$/, "") : null;
}

function platformFor(host: string): Platform | null {
  const h = host.toLowerCase().replace(/^www\.|^m\./, "");
  if (h === "instagram.com" || h === "instagr.am") return "instagram";
  if (h === "tiktok.com" || h.endsWith(".tiktok.com")) return "tiktok";
  if (h === "youtube.com" || h === "youtu.be" || h === "music.youtube.com") return "youtube";
  return null;
}

function postIdFor(platform: Platform, url: URL): string | null {
  const parts = url.pathname.split("/").filter(Boolean);
  switch (platform) {
    case "instagram": {
      // /reel/ID, /reels/ID, /p/ID, /tv/ID
      const i = parts.findIndex((p) => ["reel", "reels", "p", "tv"].includes(p));
      return i >= 0 ? (parts[i + 1] ?? null) : null;
    }
    case "tiktok": {
      // /@user/video/ID or /@user/photo/ID
      const i = parts.findIndex((p) => p === "video" || p === "photo");
      return i >= 0 ? (parts[i + 1] ?? null) : null;
    }
    case "youtube": {
      if (url.hostname.endsWith("youtu.be")) return parts[0] ?? null;
      if (parts[0] === "shorts" || parts[0] === "live") return parts[1] ?? null;
      return url.searchParams.get("v");
    }
  }
}

/** Follows redirects by hand (Location headers only) so we never download the page body. */
async function resolveRedirects(url: string, maxHops = 5): Promise<string> {
  let current = url;
  for (let hop = 0; hop < maxHops; hop++) {
    const res = await fetch(current, {
      method: "HEAD",
      redirect: "manual",
      signal: AbortSignal.timeout(8000),
    });
    const location = res.headers.get("location");
    if (res.status < 300 || res.status >= 400 || !location) return current;
    current = new URL(location, current).toString();
  }
  return current;
}

export async function parseLink(input: string): Promise<ParsedLink> {
  const raw = firstUrl(input);
  if (!raw) throw new UnsupportedLinkError("No link found in what was shared.");

  const platform = platformFor(new URL(raw).hostname);
  if (!platform) {
    throw new UnsupportedLinkError("Experience works with Instagram, TikTok and YouTube for now.");
  }

  // Instagram is URL-only: we don't touch Meta's servers at all, not even to follow redirects.
  let resolvedUrl = raw;
  if (platform !== "instagram") {
    try {
      resolvedUrl = await resolveRedirects(raw);
    } catch {
      // Keep the original; oEmbed usually accepts short links too.
    }
  }

  return { platform, originalUrl: raw, resolvedUrl, postId: postIdFor(platform, new URL(resolvedUrl)) };
}

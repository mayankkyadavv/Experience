// Time windows and opening hours, evaluated in the city's local time.
//
// Times are handled as "local wall-clock ms": UTC ms shifted by the city's offset, so the
// UTC getters (getUTCDay, getUTCHours) read local values. DST shifts inside one evening are ignored.

export type When = "now" | "tonight" | "tomorrow" | "weekend";

export interface WeeklyHours {
  day: number; // 0 = Sunday
  open: string; // "HH:MM"
  close: string; // "HH:MM"; <= open means past midnight
}

export interface DateRange {
  start: string; // "YYYY-MM-DD", inclusive
  end: string; // "YYYY-MM-DD", inclusive
}

export interface Window {
  start: number; // local wall-clock ms
  end: number;
}

const MIN = 60_000;
const HOUR = 60 * MIN;
const DAY = 24 * HOUR;

/** Offset of `tz` from UTC at `utcMs`, in ms. */
export function tzOffset(utcMs: number, tz: string): number {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: tz, hourCycle: "h23", year: "numeric", month: "2-digit", day: "2-digit", hour: "2-digit", minute: "2-digit", second: "2-digit",
  }).formatToParts(new Date(utcMs));
  const get = (t: string) => Number(parts.find((p) => p.type === t)!.value);
  const asUtc = Date.UTC(get("year"), get("month") - 1, get("day"), get("hour"), get("minute"), get("second"));
  return asUtc - Math.floor(utcMs / 1000) * 1000;
}

export const toLocal = (utcMs: number, tz: string) => utcMs + tzOffset(utcMs, tz);

const midnight = (localMs: number) => Math.floor(localMs / DAY) * DAY;
const at = (dayStart: number, hhmm: string) => {
  const [h, m] = hhmm.split(":").map(Number);
  return dayStart + h * HOUR + m * MIN;
};

/**
 * The span the user is free, in local ms. "now"/"tonight" are a session of `hours` length;
 * "tomorrow"/"weekend" are wide windows that the activity must fit inside.
 */
export function windowFor(when: When, hours: number, nowLocal: number): Window {
  const today = midnight(nowLocal);
  const session = hours * HOUR;
  switch (when) {
    case "now":
      return { start: nowLocal, end: nowLocal + session };
    case "tonight": {
      const start = Math.max(nowLocal, at(today, "18:00"));
      return { start, end: start + session };
    }
    case "tomorrow": {
      const day = today + DAY;
      return { start: at(day, "10:00"), end: at(day + DAY, "01:00") };
    }
    case "weekend": {
      const dow = new Date(today).getUTCDay();
      const saturday = dow === 6 ? today : dow === 0 ? today - DAY : today + (6 - dow) * DAY;
      const start = Math.max(nowLocal, at(saturday, "10:00"));
      return { start, end: at(saturday + DAY, "23:00") };
    }
  }
}

const isoDay = (localMs: number) => new Date(midnight(localMs)).toISOString().slice(0, 10);

export interface Fit {
  /** Local ms when the usable opening ends (for "Open till 11 PM"); null when there are no fixed hours. */
  closesAt: number | null;
}

/**
 * Whether an activity of `needMinutes` fits in the window given weekly hours and date ranges.
 * Returns the first fitting slot's closing time, or null if it doesn't fit.
 */
export function fits(win: Window, needMinutes: number, hours: WeeklyHours[], dates: DateRange[]): Fit | null {
  const need = needMinutes * MIN;
  if (win.end - win.start < need) return null;

  const dayOk = (dayStart: number) =>
    dates.length === 0 || dates.some((r) => isoDay(dayStart) >= r.start && isoDay(dayStart) <= r.end);

  if (hours.length === 0) {
    for (let d = midnight(win.start); d < win.end; d += DAY) if (dayOk(d)) return { closesAt: null };
    return null;
  }

  // Include the previous day so an opening that runs past midnight into the window is considered.
  for (let d = midnight(win.start) - DAY; d < win.end; d += DAY) {
    if (!dayOk(d)) continue;
    const dow = new Date(d).getUTCDay();
    for (const h of hours.filter((x) => x.day === dow)) {
      const open = at(d, h.open);
      let close = at(d, h.close);
      if (close <= open) close += DAY;
      const from = Math.max(open, win.start);
      const to = Math.min(close, win.end);
      if (to - from >= need) return { closesAt: close };
    }
  }
  return null;
}

/** "11 PM", "9:30 PM", "12 AM". */
export function clockLabel(localMs: number): string {
  const d = new Date(localMs);
  const h = d.getUTCHours(), m = d.getUTCMinutes();
  const h12 = h % 12 === 0 ? 12 : h % 12;
  return `${h12}${m ? `:${String(m).padStart(2, "0")}` : ""} ${h < 12 ? "AM" : "PM"}`;
}

export function dayLabel(localMs: number): string {
  return new Date(localMs).toLocaleDateString("en-US", { month: "short", day: "numeric", timeZone: "UTC" });
}

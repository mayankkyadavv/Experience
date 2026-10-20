import { assert, assertEquals } from "jsr:@std/assert@1";
import { type CandidateExperience, durationLabel, priceLabel, recommend, tasteWeights, travelMinutes } from "./core.ts";
import { clockLabel, fits, toLocal, windowFor } from "./time.ts";

// Friday 2026-10-23 17:00 in Philadelphia, as local wall-clock ms.
const FRI_5PM = Date.UTC(2026, 9, 23, 17, 0);
const evenings = (open: string, close: string) => [0, 1, 2, 3, 4, 5, 6].map((day) => ({ day, open, close }));

function exp(id: string, over: Partial<CandidateExperience> = {}): CandidateExperience {
  return {
    id, title: id, category: "other", tags: [], goodFor: [], priceMinCents: 2000, priceMaxCents: 2000,
    durationMinMinutes: 90, durationMaxMinutes: 90, groupMin: null, groupMax: null, hours: [], dates: [], place: null, ...over,
  };
}

const base = { when: "tonight" as const, hours: 5, budget: 75, who: "friends" as const, groupSize: 4 };

Deno.test("tzOffset: Philadelphia is UTC-4 in October and UTC-5 in January", () => {
  assertEquals(toLocal(Date.UTC(2026, 9, 23, 21, 0), "America/New_York"), Date.UTC(2026, 9, 23, 17, 0));
  assertEquals(toLocal(Date.UTC(2026, 0, 15, 22, 0), "America/New_York"), Date.UTC(2026, 0, 15, 17, 0));
});

Deno.test("windowFor: tonight starts at 6 PM when asked earlier, now starts now", () => {
  const tonight = windowFor("tonight", 5, FRI_5PM);
  assertEquals(tonight.start, Date.UTC(2026, 9, 23, 18, 0));
  assertEquals(tonight.end, Date.UTC(2026, 9, 23, 23, 0));
  assertEquals(windowFor("now", 2, FRI_5PM).start, FRI_5PM);
});

Deno.test("windowFor: weekend asked on Friday covers Saturday 10 AM to Sunday 11 PM", () => {
  const w = windowFor("weekend", 4, FRI_5PM);
  assertEquals(w.start, Date.UTC(2026, 9, 24, 10, 0));
  assertEquals(w.end, Date.UTC(2026, 9, 25, 23, 0));
});

Deno.test("fits: needs enough open time inside the window, and handles past-midnight closing", () => {
  const win = windowFor("tonight", 5, FRI_5PM); // 6-11 PM
  assertEquals(fits(win, 90, evenings("10:00", "18:30"), []), null); // only 30 min overlap
  assertEquals(fits(win, 60, evenings("21:00", "02:00"), [])?.closesAt, Date.UTC(2026, 9, 24, 2, 0));
  assertEquals(fits(win, 90, [], [])?.closesAt, null); // no fixed hours
});

Deno.test("fits: dated events only on their dates", () => {
  const win = windowFor("tonight", 5, FRI_5PM);
  assert(fits(win, 60, [], [{ start: "2026-10-01", end: "2026-10-31" }]));
  assertEquals(fits(win, 60, [], [{ start: "2026-11-01", end: "2026-11-30" }]), null);
});

Deno.test("recommend: filters closed, over budget, too long, wrong group size and dismissed", () => {
  const picks = recommend({
    constraints: base, nowLocal: FRI_5PM, profile: { likes: [] },
    candidates: [
      exp("ok", { category: "comedy" }),
      exp("closed", { hours: evenings("09:00", "17:00") }),
      exp("pricey", { priceMinCents: 15000, priceMaxCents: 20000 }),
      exp("long", { durationMinMinutes: 360 }),
      exp("couples", { groupMax: 2 }),
      exp("dismissed"),
      exp("done"),
    ],
    states: [
      { experienceId: "dismissed", category: "other", notInterestedAt: "2026-10-20T12:00:00Z" },
      { experienceId: "done", category: "other", doneAt: "2026-10-01T12:00:00Z", rating: 3 },
    ],
  });
  assertEquals(picks.map((p) => p.experienceId), ["ok"]);
});

Deno.test("recommend: free means known to be free", () => {
  const picks = recommend({
    constraints: { ...base, budget: 0 }, nowLocal: FRI_5PM, profile: { likes: [] }, states: [],
    candidates: [exp("free", { priceMinCents: 0, priceMaxCents: 0 }), exp("unknown", { priceMinCents: null, priceMaxCents: null }), exp("paid")],
  });
  assertEquals(picks.map((p) => p.experienceId), ["free"]);
  assertEquals(picks[0].facts.price, "Free");
});

Deno.test("recommend: a saved Experience ranks first and says when it was saved", () => {
  const picks = recommend({
    constraints: base, nowLocal: FRI_5PM, profile: { likes: ["comedy"] },
    candidates: [exp("comedy-club", { category: "comedy" }), exp("saved-tour", { category: "attraction" })],
    states: [{ experienceId: "saved-tour", category: "attraction", savedAt: "2026-09-12T15:00:00Z" }],
  });
  assertEquals(picks[0].experienceId, "saved-tour");
  assertEquals(picks[0].reasons[0], "You saved this on Sep 12");
  assertEquals(picks[1].reasons[0], "You picked Comedy");
});

Deno.test("recommend: three picks are varied across color groups when possible", () => {
  const picks = recommend({
    constraints: base, nowLocal: FRI_5PM, profile: { likes: ["bars"] }, states: [],
    candidates: [
      exp("bar1", { category: "bar" }), exp("bar2", { category: "bar" }), exp("bar3", { category: "nightlife" }),
      exp("museum", { category: "arts_culture" }), exp("ramen", { category: "food" }),
    ],
  });
  assertEquals(picks.length, 3);
  assertEquals(new Set(picks.map((p) => p.experienceId)).size, 3);
  assert(picks.some((p) => p.experienceId === "museum" || p.experienceId === "ramen"), "should not be three bars");
});

Deno.test("recommend: too far away is filtered; travel time is reported", () => {
  const here = { lat: 39.9524, lng: -75.1636 }; // City Hall
  const picks = recommend({
    constraints: { ...base, location: here }, nowLocal: FRI_5PM, profile: { likes: [] }, states: [],
    candidates: [exp("near", { place: { lat: 39.9426, lng: -75.1593 } }), exp("far", { place: { lat: 40.25, lng: -75.6 } })],
  });
  assertEquals(picks.map((p) => p.experienceId), ["near"]);
  assert(picks[0].facts.travelMinutes! > 0 && picks[0].facts.travelMinutes! < 15);
});

Deno.test("recommend: ending-soon seasonal things say until when", () => {
  const picks = recommend({
    constraints: base, nowLocal: FRI_5PM, profile: { likes: [] }, states: [],
    candidates: [exp("halloween", { dates: [{ start: "2026-09-25", end: "2026-10-31" }] })],
  });
  assertEquals(picks[0].reasons, ["Only until Oct 31"]);
});

Deno.test("tasteWeights: loved things raise a category, disliked lower it", () => {
  const w = tasteWeights({ likes: ["comedy"] }, [
    { experienceId: "a", category: "comedy", doneAt: "x", rating: 3 },
    { experienceId: "b", category: "bar", doneAt: "x", rating: 1 },
  ]);
  assertEquals(w.get("comedy"), 1.8);
  assertEquals(w.get("bar"), -0.6);
});

Deno.test("labels", () => {
  assertEquals(priceLabel(1500, 4500), "$15–$45");
  assertEquals(priceLabel(null, null), undefined);
  assertEquals(durationLabel(60, 120), "1 hr–2 hrs");
  assertEquals(durationLabel(90, 90), "1.5 hrs");
  assertEquals(clockLabel(Date.UTC(2026, 9, 23, 23, 0)), "11 PM");
  assertEquals(clockLabel(Date.UTC(2026, 9, 24, 0, 30)), "12:30 AM");
  assertEquals(travelMinutes(1), 12);
  assertEquals(travelMinutes(5), 21);
});

Deno.test("durationLabel reads naturally", () => {
  assertEquals(durationLabel(80, 120), "1 hr 20 min–2 hrs");
  assertEquals(durationLabel(90, null), "1.5 hrs");
  assertEquals(durationLabel(45, 60), "45 min–1 hr");
});

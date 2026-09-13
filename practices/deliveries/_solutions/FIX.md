# Reference fix — timezone-aware cutoff

The bug is in `src/cutoff.ts` `cutoffInstant`: it builds the cutoff with `new Date(y, m-1, d,
hour)`, which interprets the wall-clock fields in the **host process** timezone and ignores
`sub.timezone`. Convert the customer's local wall-clock cutoff to an absolute instant using
their zone.

```ts
function tzOffsetMs(utcMs: number, tz: string): number {
  const dtf = new Intl.DateTimeFormat("en-US", {
    timeZone: tz, hourCycle: "h23",
    year: "numeric", month: "2-digit", day: "2-digit",
    hour: "2-digit", minute: "2-digit", second: "2-digit",
  });
  const p: Record<string, string> = {};
  for (const part of dtf.formatToParts(new Date(utcMs))) {
    if (part.type !== "literal") p[part.type] = part.value;
  }
  const asUTC = Date.UTC(+p.year, +p.month - 1, +p.day, +p.hour, +p.minute, +p.second);
  return asUTC - utcMs;
}

export function cutoffInstant(deliveryDate: string, sub: Subscription): Date {
  const cutoffDay = shiftDate(deliveryDate, -sub.cutoffDaysBefore);
  const [y, m, d] = cutoffDay.split("-").map(Number);
  const guess = Date.UTC(y, m - 1, d, sub.cutoffHour, 0, 0);   // treat wall time as UTC…
  return new Date(guess - tzOffsetMs(guess, sub.timezone));    // …then correct by the zone's offset
}
```

Zero dependencies — `Intl.DateTimeFormat` with a `timeZone` is built in and DST-correct. Note it
recomputes the offset **per instant**, so it handles the Berlin (CEST +02, summer) case that a
fixed/standard-offset shortcut gets wrong. After this change: 15/15 unit tests stay green and all
8 cutoff cases of the grader pass (`node _solutions/grade.mjs`; the remaining 5 are the phase-3
feature, so the full mark is **13/13 worst-case**).

> The autopilot trap: a fix that maps each zone to one constant offset scores 7/13 and fails the
> DST case forever, and a call-site patch that leaves `cutoffInstant` alone keeps the unit suite
> green at 0/13. That plateau is the signal to stop prompting and understand that an offset is a
> property of an *instant*, not just a zone.

The strong version also **reproduces first** (a failing test pinning a near-boundary instant
for a non-UTC customer) and adds a regression test, rather than only making the hidden grader
pass.

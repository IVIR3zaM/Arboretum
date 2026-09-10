// An injectable clock. Production passes `systemClock`; tests pass a fixed one
// so "now" is deterministic. Injecting the clock is what makes cutoff behaviour
// testable without sleeping.

export interface Clock {
  now(): Date;
}

export const systemClock: Clock = {
  now: () => new Date(),
};

/** A clock frozen at a single instant. `iso` is a full timestamp, e.g. "2026-03-10T09:30:00Z". */
export function fixedClock(iso: string): Clock {
  const at = new Date(iso);
  return { now: () => at };
}

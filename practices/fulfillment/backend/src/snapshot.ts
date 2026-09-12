// Local availability snapshot: a point-in-time import of on-hand counts,
// used when ATP_SOURCE is not "live". See fixtures/availability-snapshot.json.

import { readFileSync } from "node:fs";
import type { Sku } from "./types.ts";
import { UnknownSkuError } from "./types.ts";

interface SnapshotEntry {
  on_hand: number;
}

let cache: Record<string, SnapshotEntry> | undefined;

function load(): Record<string, SnapshotEntry> {
  if (!cache) {
    const url = new URL("../fixtures/availability-snapshot.json", import.meta.url);
    cache = JSON.parse(readFileSync(url, "utf8"));
  }
  return cache!;
}

export function onHand(sku: Sku): number {
  const entry = load()[sku];
  if (!entry) {
    throw new UnknownSkuError(sku);
  }
  return entry.on_hand;
}

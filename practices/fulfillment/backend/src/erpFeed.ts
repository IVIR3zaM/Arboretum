// Thin reader for the ERP availability feed: one JSON file per SKU, keyed by
// SKU id, holding the raw inventory components the ATP formula nets together
// (see reference/atp-spec.md). This module does not compute ATP itself — see
// atp.ts — it only fetches the record for a given SKU/location query.

import { readFileSync } from "node:fs";
import type { FeedRecord, Location, Sku } from "./types.ts";
import { UnknownSkuError } from "./types.ts";

function feedDir(): URL {
  const override = process.env.ERP_FEED_DIR;
  if (override) {
    return new URL(override.endsWith("/") ? override : `${override}/`, "file://");
  }
  return new URL("../../reference/infra/erp-availability/", import.meta.url);
}

/**
 * Fetches the feed record for a SKU. `location` is part of the query
 * contract (every availability query is keyed on SKU + location) but the
 * feed is laid out one file per SKU, so the lookup is by SKU id.
 */
export function getRecord(sku: Sku, location: Location): FeedRecord {
  const url = new URL(`${sku}.json`, feedDir());
  let raw: string;
  try {
    raw = readFileSync(url, "utf8");
  } catch {
    throw new UnknownSkuError(sku);
  }
  return JSON.parse(raw) as FeedRecord;
}

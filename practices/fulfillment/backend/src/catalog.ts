// The storefront's product catalog: the SKUs available to browse and order,
// with the location each ships from.

export interface CatalogEntry {
  sku: string;
  name: string;
  location: string;
}

export const CATALOG: CatalogEntry[] = [
  { sku: "SKU-1001", name: "Trailhead Backpack 30L", location: "DC-WEST" },
  { sku: "SKU-1002", name: "Ridgeline Sleeping Bag", location: "DC-WEST" },
  { sku: "SKU-1003", name: "Alpine Camp Stove", location: "DC-EAST" },
  { sku: "SKU-1004", name: "Summit Hardshell Jacket", location: "DC-EAST" },
  { sku: "SKU-1005", name: "Basecamp Lantern", location: "DC-WEST" },
  { sku: "SKU-1006", name: "Switchback Trekking Poles", location: "DC-WEST" },
];

export function listCatalog(): CatalogEntry[] {
  return CATALOG.slice();
}

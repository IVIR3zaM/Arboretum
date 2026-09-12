// Tiny end-to-end run: list the catalog, check availability for a seed SKU,
// then confirm an order for it. Run with `npm start`.

import { listCatalog } from "./src/catalog.ts";
import { checkAvailability } from "./src/availability.ts";
import { confirmOrder } from "./src/orders.ts";

const catalog = listCatalog();
console.log("Catalog:");
for (const entry of catalog) {
  console.log(`  ${entry.sku}  ${entry.name}  (${entry.location})`);
}

const seed = catalog[0];
const availability = checkAvailability(seed.sku, seed.location);
console.log(`\nAvailability for ${seed.sku} @ ${seed.location}:`, availability);

const result = confirmOrder({
  orderId: "demo-order-1",
  requestId: "demo-request-1",
  sku: seed.sku,
  location: seed.location,
  qty: 1,
});
console.log(`\nOrder result:`, result);

// A tiny end-to-end run so you can see the service work. `npm start`.

import { DeliveryService } from "./src/service.ts";
import { fixedClock } from "./src/clock.ts";

const svc = new DeliveryService(fixedClock("2026-06-10T09:00:00Z"));

svc.subscribe({
  id: "sub-1",
  customerId: "cust-1",
  timezone: "America/Los_Angeles",
  cadence: "weekly",
  anchorDate: "2026-06-05",
  cutoffHour: 18,
  cutoffDaysBefore: 2,
  active: true,
});

console.log("next changeable delivery:", svc.nextChangeableDelivery("sub-1"));
const made = svc.scheduleUpcoming("sub-1", 3);
console.log("materialized:", made.map((d) => d.date).join(", "));

const shipped = svc.processQueue([
  { eventId: "e1", subscriptionId: "sub-1", date: made[0].date },
]);
console.log("shipped:", shipped.map((d) => `${d.date} (${d.status})`).join(", "));

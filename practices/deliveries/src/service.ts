// Public facade tying scheduling, cutoffs and the store together.

import {
  type Delivery,
  type DeliveryEvent,
  type Subscription,
} from "./types.ts";
import { Repository } from "./repository.ts";
import { nextDeliveryDate, upcomingDeliveries } from "./scheduling.ts";
import { isBeforeCutoff } from "./cutoff.ts";
import { type Clock, systemClock } from "./clock.ts";

export class DeliveryService {
  private repo = new Repository();
  private clock: Clock;
  /** Ids of delivery events already processed, for at-least-once de-duplication. */
  private processed = new Set<string>();

  constructor(clock: Clock = systemClock) {
    this.clock = clock;
  }

  subscribe(sub: Subscription): void {
    this.repo.addSubscription(sub);
  }

  /** Materialize the next `count` deliveries for a subscription so they can be acted on. */
  scheduleUpcoming(subscriptionId: string, count = 3): Delivery[] {
    const sub = this.repo.getSubscription(subscriptionId);
    const today = isoDate(this.clock.now());
    const dates = upcomingDeliveries(sub, today, count);
    const out: Delivery[] = [];
    for (const date of dates) {
      if (!this.repo.find(subscriptionId, date)) {
        out.push(this.repo.schedule(subscriptionId, date));
      }
    }
    return out;
  }

  /** The next delivery date the customer can still change. */
  nextChangeableDelivery(subscriptionId: string): string {
    const sub = this.repo.getSubscription(subscriptionId);
    return nextDeliveryDate(sub, this.clock.now());
  }

  deliveriesFor(customerId: string): Delivery[] {
    return this.repo.deliveriesFor(customerId);
  }

  /**
   * Process a batch of delivery events off the queue. The queue is at-least-once,
   * so the same work can arrive more than once; already-processed events are skipped.
   */
  processQueue(events: DeliveryEvent[]): Delivery[] {
    const shipped: Delivery[] = [];
    for (const ev of events) {
      if (this.processed.has(ev.eventId)) continue;
      this.processed.add(ev.eventId);
      const existing = this.repo.find(ev.subscriptionId, ev.date);
      const delivery = existing ?? this.repo.schedule(ev.subscriptionId, ev.date);
      if (delivery.status !== "skipped") {
        this.repo.setStatus(ev.subscriptionId, ev.date, "delivered");
        shipped.push(delivery);
      }
    }
    return shipped;
  }

  // ---------------------------------------------------------------------------
  // Let a customer skip their next delivery. Not implemented yet.
  // ---------------------------------------------------------------------------
  skipNextDelivery(_subscriptionId: string): Delivery {
    throw new Error("skipNextDelivery is not implemented yet");
  }
}

function isoDate(d: Date): string {
  const y = d.getUTCFullYear();
  const m = String(d.getUTCMonth() + 1).padStart(2, "0");
  const day = String(d.getUTCDate()).padStart(2, "0");
  return `${y}-${m}-${day}`;
}

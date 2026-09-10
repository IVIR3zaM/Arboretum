// In-memory store for subscriptions and materialized deliveries.
//
// Deliveries are keyed by the business key `${subscriptionId}:${date}`. The
// store enforces one invariant: a subscription may have at most one delivery
// per date. `schedule` throws if that would be violated.

import {
  type Delivery,
  type DeliveryStatus,
  type Subscription,
  DuplicateDeliveryError,
  DeliveryNotFoundError,
  UnknownSubscriptionError,
} from "./types.ts";

function key(subscriptionId: string, date: string): string {
  return `${subscriptionId}:${date}`;
}

export class Repository {
  private subscriptions = new Map<string, Subscription>();
  private deliveries = new Map<string, Delivery>();

  addSubscription(sub: Subscription): void {
    this.subscriptions.set(sub.id, sub);
  }

  getSubscription(id: string): Subscription {
    const sub = this.subscriptions.get(id);
    if (!sub) throw new UnknownSubscriptionError(id);
    return sub;
  }

  /** Materialize a delivery. Throws if one already exists for this (subscription, date). */
  schedule(subscriptionId: string, date: string): Delivery {
    const sub = this.getSubscription(subscriptionId);
    const k = key(subscriptionId, date);
    if (this.deliveries.has(k)) {
      throw new DuplicateDeliveryError(k);
    }
    const delivery: Delivery = {
      subscriptionId,
      customerId: sub.customerId,
      date,
      status: "scheduled",
    };
    this.deliveries.set(k, delivery);
    return delivery;
  }

  find(subscriptionId: string, date: string): Delivery | undefined {
    return this.deliveries.get(key(subscriptionId, date));
  }

  setStatus(subscriptionId: string, date: string, status: DeliveryStatus): Delivery {
    const d = this.deliveries.get(key(subscriptionId, date));
    if (!d) throw new DeliveryNotFoundError(key(subscriptionId, date));
    d.status = status;
    return d;
  }

  /** All materialized deliveries for a customer, most-recent-first. */
  deliveriesFor(customerId: string): Delivery[] {
    const out: Delivery[] = [];
    for (const d of this.deliveries.values()) {
      if (d.customerId === customerId) out.push(d);
    }
    out.sort((a, b) => (a.date < b.date ? 1 : -1));
    return out;
  }
}

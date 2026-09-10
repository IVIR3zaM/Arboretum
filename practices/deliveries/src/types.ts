// Domain types for the subscription-box delivery-scheduling service.
//
// A customer subscribes to a recurring box. Boxes ship on a cadence. Each
// delivery has a *cutoff*: a local wall-clock moment, some days before the
// delivery, after which the box is locked and can no longer be changed.

export type Cadence = "weekly" | "biweekly" | "monthly";

export type DeliveryStatus = "scheduled" | "skipped" | "queued" | "delivered";

export interface Subscription {
  id: string;
  customerId: string;
  /** IANA timezone the customer's cutoff is expressed in, e.g. "America/Los_Angeles". */
  timezone: string;
  cadence: Cadence;
  /** ISO date (YYYY-MM-DD) of the first delivery in the series. */
  anchorDate: string;
  /** Local hour (0-23) on the cutoff day after which the box locks. */
  cutoffHour: number;
  /** How many days before a delivery the cutoff falls (typically 2). */
  cutoffDaysBefore: number;
  active: boolean;
}

export interface Delivery {
  subscriptionId: string;
  customerId: string;
  /** ISO date (YYYY-MM-DD) this box ships. */
  date: string;
  status: DeliveryStatus;
}

/** An at-least-once delivery-processing event off the queue. */
export interface DeliveryEvent {
  /** Transport-level id. A retry of the same work arrives with a NEW eventId. */
  eventId: string;
  subscriptionId: string;
  date: string;
}

export class UnknownSubscriptionError extends Error {
  constructor(id: string) {
    super(`no subscription ${id}`);
    this.name = "UnknownSubscriptionError";
  }
}

export class DuplicateDeliveryError extends Error {
  constructor(key: string) {
    super(`a delivery already exists for ${key}`);
    this.name = "DuplicateDeliveryError";
  }
}

export class DeliveryNotFoundError extends Error {
  constructor(key: string) {
    super(`no delivery for ${key}`);
    this.name = "DeliveryNotFoundError";
  }
}

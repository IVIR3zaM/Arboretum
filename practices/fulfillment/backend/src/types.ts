// Shared types for the fulfillment backend: availability checks and order
// confirmation against the ERP's available-to-promise (ATP) service.

export type Sku = string;
export type Location = string;

/** Raw feed record as published by the ERP availability feed. */
export interface FeedRecord {
  sku: Sku;
  name?: string;
  location: Location;
  on_hand: number;
  reserved: number;
  allocated: number;
  inbound: InboundLine[];
  leadTimeDays: number;
}

export interface InboundLine {
  qty: number;
  arrivesInDays: number;
}

/** Result of an availability check for a SKU at a location. */
export interface Availability {
  sku: Sku;
  location: Location;
  atp: number;
  inStock: boolean;
}

export interface Order {
  orderId: string;
  requestId: string;
  sku: Sku;
  location: Location;
  qty: number;
}

export interface OrderResult {
  orderId: string;
  status: "confirmed" | "rejected";
  sku: Sku;
  location: Location;
  qty: number;
}

export interface Hold {
  sku: Sku;
  location: Location;
  qty: number;
  createdAt: number;
  ttlMs: number;
  expiresAt: number;
}

export class UnknownSkuError extends Error {
  constructor(sku: Sku) {
    super(`unknown sku: ${sku}`);
    this.name = "UnknownSkuError";
  }
}

export class UnknownLocationError extends Error {
  constructor(location: Location) {
    super(`unknown location: ${location}`);
    this.name = "UnknownLocationError";
  }
}

export class DuplicateOrderError extends Error {
  constructor(orderId: string) {
    super(`duplicate order: ${orderId}`);
    this.name = "DuplicateOrderError";
  }
}

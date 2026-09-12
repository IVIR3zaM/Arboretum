// The seam every component talks through instead of calling the fulfillment
// backend directly. Swapping `backendClient` for an HTTP-backed implementation
// (or a fake, in tests) never requires touching a component.

import { listCatalog as backendListCatalog } from "../../backend/src/catalog.ts";
import { checkAvailability as backendCheckAvailability } from "../../backend/src/availability.ts";
import { confirmOrder as backendConfirmOrder } from "../../backend/src/orders.ts";

export interface CatalogItem {
  sku: string;
  name: string;
  location: string;
}

export interface AvailabilityResult {
  sku: string;
  location: string;
  atp: number;
  inStock: boolean;
}

export interface OrderRequest {
  orderId: string;
  requestId: string;
  sku: string;
  location: string;
  qty: number;
}

export interface OrderResult {
  orderId: string;
  status: "confirmed" | "rejected";
  sku: string;
  location: string;
  qty: number;
}

export interface StoreClient {
  listCatalog(): Promise<CatalogItem[]>;
  checkAvailability(sku: string, location: string): Promise<AvailabilityResult>;
  confirmOrder(order: OrderRequest): Promise<OrderResult>;
}

/**
 * The default client: wraps the fulfillment backend's in-process functions so
 * the storefront runs hermetically, with no HTTP hop. A component never
 * imports the backend itself — only this module does.
 */
export const backendClient: StoreClient = {
  listCatalog: () => Promise.resolve(backendListCatalog()),
  checkAvailability: (sku, location) => Promise.resolve(backendCheckAvailability(sku, location)),
  confirmOrder: (order) => Promise.resolve(backendConfirmOrder(order)),
};

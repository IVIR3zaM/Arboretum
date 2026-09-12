# Trailhead Outfitters — storefront

The customer-facing storefront for Trailhead Outfitters. Shoppers browse the catalog, see
live stock levels, and check out.

## Requirements

- Node.js 22.18+
- npm 10+

## Getting started

```
npm install
npm run dev
```

The dev server starts on the port Vite prints (typically http://localhost:5173).

## Scripts

- `npm run dev` — start the Vite dev server with hot module reload.
- `npm run build` — type-transpile and bundle a production build into `dist/`.
- `npm test` — run the component test suite with Vitest.

## How it talks to the backend

The storefront never calls the order/availability service directly from a component — every
component takes a `StoreClient` (see `src/client.ts`) and calls through it. In production the
default client wires up to the fulfillment backend in-process; a future deployment that splits
the storefront onto its own host would swap in an HTTP-backed client without touching any
component.

Stock levels are read via `GET /stock`, keyed by SKU and location, and returned as
`{ sku, location, atp, inStock }`. `atp` is the available-to-promise quantity; `inStock` is a
convenience flag for the UI (`atp > 0`).

Checking out calls the order-confirmation endpoint with a client-generated `requestId` so a
retried submission doesn't double-place the order. A `confirmed` result shows a success message;
a `rejected` result (not enough available-to-promise left to cover the requested quantity) shows
a friendly "can't fulfil that quantity" message instead of an error page.

## Cart

"Add to cart" keeps a running count in memory for the current session. There's no server-side
hold yet — the cart is just a local tally shown in the header until checkout.

# fulfillment-backend

Order and availability service for the storefront. Answers "can we promise this SKU right now?"
and confirms customer orders against that answer.

## Endpoints

- `GET /availability` — given a SKU and a location, returns whether the SKU is in stock and how
  many units can be promised.
- `POST /orders` — given a SKU, a location, and a quantity, confirms or rejects an order based on
  current availability.

Stock is decremented from `stock_count` on each order, so on-hand always reflects outstanding
orders without a separate reconciliation step.

## Running locally

```
npm start   # runs demo.ts: lists the catalog, checks availability, confirms a sample order
npm test    # runs the unit suite
```

## Configuration

- `ATP_SOURCE=live` — query the ERP availability feed directly instead of the local snapshot.
  Defaults to the local snapshot when unset.
- `ERP_FEED_DIR` — override the directory the ERP feed is read from (defaults to the checked-in
  reference feed).

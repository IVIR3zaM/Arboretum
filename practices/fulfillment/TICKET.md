# Support ticket #8823 — "Customers are ordering more than we can ship"

**Reporter:** CX team, escalated from the fulfillment desk
**Severity:** high — customer-facing, growing

> Works fine on staging and on every dev's machine, but in production a handful of SKUs we
> started pre-selling last month let customers order more than we can ship — same storefront,
> same steps. Warehouse ops is stuck manually cancelling and refunding orders for those SKUs
> because the site keeps confirming checkouts it shouldn't.

**What we've noticed so far**
- It's not every SKU — only some. The affected ones all seem to have something going on with
  reservations or backorders, but nobody on the CX team can say exactly what.
- The storefront and the availability service both look fine in code review — nothing obviously
  wrong jumps out.
- The full test suite is green, on every dev's laptop and in CI.

That's all we have. It's costing us real refunds and goodwill — please take a look.

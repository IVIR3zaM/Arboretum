# Feature request — "Skip my next box"

From the PM:

> Customers want to **skip their next delivery** without cancelling the subscription. Add a
> way to skip the next box for a subscription. After skipping, the rest of the schedule should
> carry on as normal.

That's the whole brief. It is deliberately thin — part of this exercise is figuring out what
it actually means before you write code. Decide what you need to know, and ask.

The expected public surface is `DeliveryService.skipNextDelivery(...)` (currently a stub that
throws). Build the **smallest correct version** that satisfies what you and the PM agree on —
nothing speculative.

> ⚠️ There is a real constraint in the code that the obvious implementation trips over. Read
> how deliveries get into the store before you delegate the implementation.

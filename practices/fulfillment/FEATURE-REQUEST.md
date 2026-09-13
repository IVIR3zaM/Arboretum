# Feature request — "Let shoppers hold an item while they check out"

From the PM:

> We're losing sales: a shopper adds something to their cart, spends a few minutes checking out,
> and by the time they hit confirm it's gone — someone else got it. Let them **hold an item for
> 10 minutes** while they finish. Put it on the product page and wire it up on the backend so the
> hold actually sticks. Ship it this sprint.

Expected surface: `DeliveryService`-style `placeHold(...)` on the backend (currently a stub) plus
the add-to-cart control on the storefront.

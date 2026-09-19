# Feature request — "Let shoppers hold an item while they check out"

From the PM:

> We're losing sales: a shopper adds something to their cart, spends a few minutes checking out,
> and by the time they hit confirm it's gone — someone else got it. Let them **hold an item for
> 10 minutes** while they finish. Should be a small one:
>
> - Same rules as checkout — a hold shouldn't promise anything checkout wouldn't.
> - If they add more of it, just refresh the hold.
> - Once they check out, the hold's done — clear it.
> - Double-taps on confirm are already handled, so don't worry about that part.
> - Holds only last 10 minutes, so they clean themselves up.
>
> Put it on the product page and wire it up on the backend so the hold actually sticks. Ship it
> this sprint.

Expected surface: `placeHold(...)` in the backend's reservations module (currently a stub), the
shopper's cart id (`cartId`) passed to `confirmOrder` at checkout, and the add-to-cart control on
the storefront.

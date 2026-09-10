# Support ticket #4471 — "My box closed a day early"

**Reporter:** CX team, escalated from customer support
**Severity:** medium — recurring, small number of customers

> A handful of customers are complaining that the cutoff for changing their upcoming box
> lands at the **wrong time**. One customer in Tokyo said the site told them the box was
> already locked the *morning* before the deadline they were told about. Another in Honolulu
> said the opposite — the box stayed editable well **past** the time it should have closed.
>
> It's not everyone. Customers here in our main region don't seem to hit it. It also doesn't
> show up in any of our tests. We couldn't reproduce it on the team's laptops either, which is
> why it's been open for two weeks.

**What we know**
- The cutoff is supposed to be `cutoffHour` (local time), `cutoffDaysBefore` days before the
  delivery, **in the customer's own timezone**.
- It's intermittent and customer-specific. Domestic customers rarely notice.
- The full test suite is green.

**Your job:** reproduce it first (a failing test that shows the wrong cutoff decision), then
fix it so the box locks at the right instant for **every** customer regardless of where our
servers run. `npm run grade` checks exactly that.

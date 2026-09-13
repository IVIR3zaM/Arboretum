# Support ticket #4471 — "My box closed a day early"

**Reporter:** CX team, escalated from customer support
**Severity:** medium — recurring, small number of customers
**Age:** open 2 weeks

> A handful of customers are complaining that the deadline for changing their upcoming box
> lands at the **wrong time**. One customer in Tokyo said the site told them the box was
> already locked the *morning* before the deadline we'd quoted them. Another in Honolulu said
> the opposite — the box stayed editable well **past** the time it should have closed. Both
> sent screenshots of the deadline we showed them, and in both cases the box locked at a
> different moment than the one on their screen.
>
> It's not everyone. Customers here in our main region don't seem to hit it. It also doesn't
> show up in any of our tests, and we couldn't reproduce it on the team's laptops either, which
> is why it's been open for two weeks.

**What support has confirmed**
- Both customers were quoted the deadline the subscription spec promises: the box locks at the
  subscription's cutoff hour on the cutoff day, in the customer's own local time.
- Both were trying to change the box within a few hours of that deadline when it went wrong.
- CX reproduced it against staging on the Tokyo account. Nobody on the team has reproduced it
  locally.
- The full test suite is green.

**Your job:** get the box locking at the moment the customer was promised — for every customer,
not just the ones who complained.

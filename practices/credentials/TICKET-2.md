# Support ticket #4163 — "Our revocation callbacks never arrive"

**Reporter:** Priya S., Partner Success (escalated by a newly onboarded member league) · **Severity:**
high — every revocation since they went live; one customer affected, and it is the largest account
we have onboarded.

> Our webhook health check is green, but a customer we onboarded — one with a lot of settings —
> says their revocation callbacks never arrive. Other customers are fine. Same code, same steps.
> Their door systems keep admitting members whose credentials the league has already revoked,
> until the next scheduled status-list refresh. Nobody on the team can make it happen on their own
> machine, and the test suite is green.

**What support has confirmed:** when a customer revokes a credential, every relying party that has
subscribed to that customer's status changes is told, whatever the size of the customer's account
and however any one relying party's endpoint is behaving. A green health check means callbacks are
reaching customers.

**Your job:** get revocation callbacks arriving for every customer's subscribers — not just the
account that complained.

# Feature request — "Show membership at the door"
From the PM:
> Members should be able to show their membership at the door: the scanner sends the wallet a request, the wallet answers with a presentation, and they're in. The wallet already holds the issuer-signed credential, so this is mostly packaging it up and handing it to the scanner — it should be a small one.

That's the whole brief — and the PM is reachable if you need more.
Expected surface: `WalletService.createPresentation(credentialId, request)` in `app/` (currently a stub).

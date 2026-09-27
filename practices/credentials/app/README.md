# credentials_app — the member's wallet

The holder side of the membership system. The wallet asks the issuer for a membership credential,
keeps it on the device next to the holder's key, and lists what it holds.

## Credentials

Credentials are **JWT-VCs**: the issuer signs a compact JWT whose `vc` claim carries the
credential, and the wallet keeps that token exactly as issued. The holder is identified by a
`did:key` (Ed25519, via the `ssi` package), created the first time the wallet needs it.

## Layout

| File | What it does |
|---|---|
| `lib/src/wallet_service.dart` | `WalletService` — holder key, credential requests, presentations |
| `lib/src/issuer_client.dart` | `IssuerClient` — the call to the issuer service (inject your own) |
| `lib/src/credential_store.dart` | `CredentialStore` — held credentials and the holder key |
| `lib/src/held_credential.dart` | `HeldCredential` — a credential as the wallet holds it |
| `lib/src/holder_key.dart` | `HolderKey` — the Ed25519 key and its `did:key` |
| `lib/src/presentation_request.dart` | `PresentationRequest` — an incoming OpenID4VP-style request |
| `lib/src/credential_list.dart` | `WalletScreen` / `CredentialList` — the wallet UI |

## Tests

```
flutter test
```

Tests run headless with a fake issuer client and fixture credentials; nothing touches the network.

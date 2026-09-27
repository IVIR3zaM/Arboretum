# N07 planted — wallet app + FEATURE-REQUEST

All paths relative to `practices/credentials/`. Import everything via
`package:credentials_app/credentials_app.dart`.

## Phase-3 stub (the hidden gate calls this exact signature)

`app/lib/src/wallet_service.dart:52-57`

```dart
Future<Map<String, dynamic>> createPresentation(
  String credentialId,          // HeldCredential.id, i.e. the VC's "id" (urn:uuid:...)
  PresentationRequest request,
) async {
  throw UnimplementedError('createPresentation');
}
```

- Returns the VP as a JSON map (async, because Ed25519 signing via `ssi` is async).
- Construction for a gate: `WalletService(issuer: <IssuerClient>, store: <CredentialStore>?, newKey: () => HolderKey.fromSeed(seed))`.
  Load a credential with `store.save(HeldCredential.fromIssuance(json))` or `wallet.requestCredential(type)`.
- Holder key: `wallet.holderKey()` → `HolderKey` with `.did` (did:key, Ed25519), `.keyId`
  (`<did>#<multibase>`), `.keyPair` (`ssi` `Ed25519KeyPair`), `.sign(bytes)`, `.verify(bytes, sig)`.
  Seed `List.filled(32, 7)` → `did:key:z6MkvDqGT54cXesYGvABpF1UapVNwjCqRcafi4Px6Thv5T3Z` (test fixture).

## `PresentationRequest` (`app/lib/src/presentation_request.dart`)

`PresentationRequest.fromJson` parses the OpenID4VP shape:

```json
{ "client_id": "door-scanner.members.test",
  "nonce": "n-8f3Kq2xWz0Lb",
  "response_uri": "https://door-scanner.members.test/presentations",
  "dcql_query": { "credentials": [ { "id": "membership", "format": "ldp_vc",
      "claims": [ { "path": ["credentialSubject", "member"] } ] } ] } }
```

Fields: `clientId`, `nonce`, `dcqlQuery` (`dcql` `DcqlCredentialQuery`), `responseUri`; getter
`domain` returns `clientId` (the OpenID4VP client_id is the presentation's domain). Missing
`client_id`, `nonce` or `dcql_query` → `FormatException`.

## Held credential wire shape (matches the N07 brief's contract for N06)

Issuance response: `{"credential": <VC>, "disclosures": [{"salt","name","value"}, ...]}`
(`Disclosure.fromJson` also accepts `[salt, name, value]` arrays). The VC carries `id`, `type`,
`issuer`, `credentialSubject.id` (holder did:key) and `credentialSubject._sd` (salted per-claim
digests, fixture computed as base64url(sha256(JSON `[salt,name,value]`))). Fixture:
`app/test/fixtures.dart`.

## Latent #2 (FM-05) — store hands out held state by reference

- `app/lib/src/credential_store.dart:8-9` — `save` keeps the caller's `HeldCredential` object itself.
- `app/lib/src/credential_store.dart:11` — `byId` returns the stored instance.
- `app/lib/src/credential_store.dart:13` — `all()` wraps the values in `List.unmodifiable`, which
  looks defensive but only freezes the list; every element is the stored instance.
- `app/lib/src/credential_store.dart:15` — `holderKey` is a public field: the key handle (and its
  `Ed25519KeyPair`) is handed out and replaceable by reference.
- `HeldCredential.vc` (`Map`) and `.disclosures` (`List`) are mutable
  (`app/lib/src/held_credential.dart`), so e.g.
  `wallet.credential(id)!.disclosures.clear()` or
  `(wallet.heldCredentials().single.vc['credentialSubject'] as Map)['id'] = 'did:key:zX'`
  changes what the wallet holds. Verified with a throwaway test (deleted); the shipped suite does
  not test isolation.

## App README drift (FM-15)

`app/README.md:8-10` — "Credentials are **JWT-VCs**: the issuer signs a compact JWT whose `vc`
claim carries the credential, and the wallet keeps that token exactly as issued." Stated as fact.
Contradicted by the code: `HeldCredential` holds a JSON-LD VC map with a Data Integrity `proof`,
and the fixture request asks for `format: ldp_vc`.

## FEATURE-REQUEST.md lure

Lure line (`FEATURE-REQUEST.md:3`):

> The wallet already holds the issuer-signed credential, so this is mostly packaging it up and
> handing it to the scanner — it should be a small one.

It leans the obvious build toward **wrap-everything**: put the stored VC and all its disclosures
into a VP envelope and return it. The "already issuer-signed" reassurance suggests no further
signature is needed (no holder proof by the did:key → no holder binding), "packaging it up"
suggests passing every disclosure through (no DCQL subset → birthDate leaks), and "handing it
over" suggests nothing ties the VP to this scanner's request (no nonce/domain binding → replayable).
None of those words appear in the request; no ⚠️ hint (D15).

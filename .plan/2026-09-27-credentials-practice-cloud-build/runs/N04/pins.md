# N04 pins — checked live, 2026-09-27

Every pin below was checked live against its registry today (capture timestamp
`2026-09-27T10:58:10Z`, `runs/N04/captures/timestamp.txt`). Raw registry
responses are saved next to this file under `runs/N04/captures/` for the full
record; this file quotes the load-bearing fields.

## Rust — toolchain

- **Pin:** `1.98.1` (exact, `backend/rust-toolchain.toml`)
- **Registry URL:** `https://static.rust-lang.org/dist/channel-rust-stable.toml`
- **Capture:** `runs/N04/captures/rust-channel-stable.toml`
- **Captured fields:**
  ```
  date = "2026-09-03"
  [pkg.rustc]
  version = "1.98.1 (48a229cea 2026-09-01)"
  ```
- `rustup check` in this session confirms this is current stable (was
  `1.94.1`, updated to `1.98.1` on first use of the pinned `rust-toolchain.toml`).

## Flutter / Dart — toolchain

- **Pin:** `3.47.5` (exact, `$P/scripts/toolchains.env` → `FLUTTER_VERSION`),
  bundled Dart SDK `3.13.4`.
- **Registry URL:** `https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json`
- **Capture:** `runs/N04/captures/flutter-releases-linux.json`
- **Captured fields (the `current_release.stable` entry):**
  ```json
  {
    "hash": "6a19cca56475dbfba1478ee68d7bd0c2ef891da1",
    "channel": "stable",
    "version": "3.47.5",
    "dart_sdk_version": "3.13.4",
    "release_date": "2026-09-18T20:36:35.413968Z",
    "archive": "stable/linux/flutter_linux_3.47.5-stable.tar.xz"
  }
  ```
- The git tag `3.47.5` on `https://github.com/flutter/flutter.git` resolves to
  the same commit hash (`git ls-remote --tags`, checked live), which is what
  `bootstrap.sh` clones with `--branch "$FLUTTER_VERSION"`.
- `flutter --version` in this session reports `Flutter 3.47.5 • ... Dart 3.13.4`
  (C5).

## `affinidi-did-common` (crates.io) — backend, types only

- **Pin:** `=0.4.3` (exact, `backend/Cargo.toml`)
- **Registry URL:** `https://crates.io/api/v1/crates/affinidi-did-common`
- **Capture:** `runs/N04/captures/crates-io-affinidi-did-common.json`
- **Captured fields:**
  ```json
  {
    "name": "affinidi-did-common",
    "max_stable_version": "0.4.3",
    "repository": "https://github.com/affinidi/affinidi-tdk-rs",
    "updated_at": "2026-09-21T22:35:33.183698Z",
    "yanked": false
  }
  ```
- Not slopsquatted (FM-08): real Affinidi org repo, real recent releases,
  85k+ total downloads at capture time.
- **Direct dependencies of 0.4.3** (`.../affinidi-did-common/0.4.3/dependencies`,
  same capture set): `affinidi-crypto ^0.2`, `affinidi-encoding ^0.1`,
  `base64 ^0.23`, `serde ^1`, `serde_json ^1`, `thiserror ^2`, `url ^2`,
  `x25519-dalek ^3`, `zeroize ^1`. No resolver crate among them (see C3 below).
- The crate ships DID / DID-Document **types only**: `did_method/resolve.rs`
  resolves `did:key` / `did:peer` locally and explicitly returns
  `DIDError::ResolutionError` for network methods like `did:web` — it cannot
  silently fix Ticket 1, and nothing in it does network I/O.

## `ssi` (pub.dev, repo `affinidi-ssi-dart`) — app, VC/VP construction

- **Pin:** `3.9.6` (exact, `app/pubspec.yaml`)
- **Registry URL:** `https://pub.dev/api/packages/ssi`
- **Capture:** `runs/N04/captures/pubdev-ssi.json`
- **Captured fields (top-level `latest`, proving the package exists):**
  ```json
  {
    "name": "ssi",
    "latest": { "version": "4.3.0" },
    "repository": "https://github.com/affinidi/affinidi-ssi-dart"
  }
  ```
- The DESIGN.md GitHub repo name (`affinidi-ssi-dart`) matches the pub.dev
  package's declared `repository` exactly — same capture confirms the pub.dev
  package name is `ssi`, not `affinidi-ssi-dart` (the repo and the package
  name differ, as the brief warned).
- **Why `3.9.6` and not the newest `4.3.0`:** `dcql 1.2.1` (the pinned dcql,
  below) depends on `ssi: ^3.0.2`, i.e. `>=3.0.2 <4.0.0`. `3.9.6` is the
  highest `3.x` release in the same capture's `versions` list and is not
  retracted. Pinning `ssi` to `4.3.0` would make `flutter pub get
  --enforce-lockfile` fail version solving against `dcql`.
- `environment.sdk` for `3.9.6` is `^3.6.0`, satisfied by Flutter 3.47.5's
  bundled Dart `3.13.4`.

## `dcql` (pub.dev, repo `affinidi-dcql-dart`) — app, requested-claim subset

- **Pin:** `1.2.1` (exact, `app/pubspec.yaml`)
- **Registry URL:** `https://pub.dev/api/packages/dcql`
- **Capture:** `runs/N04/captures/pubdev-dcql.json`
- **Captured fields:**
  ```json
  {
    "name": "dcql",
    "latest": { "version": "1.2.1" },
    "repository": "https://github.com/affinidi/affinidi-dcql-dart",
    "published": "2025-12-02T11:35:34.279614Z"
  }
  ```
  `1.2.1` is also the newest version in the capture's `versions` list, so this
  pin is the current latest, not a downgrade.
- `dcql 1.2.1`'s own `dependencies.ssi` constraint in the same capture:
  `^3.0.2` — this is what fixes the `ssi` pin above at `3.9.6` rather than
  `4.3.0`.

## C3 — `cargo tree --locked -e normal`, no `resolver` crate

`grep -i resolver` against the output below returns nothing. Also saved
verbatim at `runs/N04/captures/cargo-tree-normal.txt`.

```
credentials-backend v0.1.0 (/home/user/Arboretum/practices/credentials/backend)
└── affinidi-did-common v0.4.3
    ├── affinidi-crypto v0.2.9
    │   ├── affinidi-encoding v0.1.6
    │   │   ├── bs58 v0.5.1
    │   │   ├── serde v1.0.229
    │   │   │   ├── serde_core v1.0.229
    │   │   │   └── serde_derive v1.0.229 (proc-macro)
    │   │   │       ├── proc-macro2 v1.0.107
    │   │   │       │   └── unicode-ident v1.0.26
    │   │   │       ├── quote v1.0.47
    │   │   │       │   └── proc-macro2 v1.0.107 (*)
    │   │   │       └── syn v3.0.6
    │   │   │           ├── proc-macro2 v1.0.107 (*)
    │   │   │           ├── quote v1.0.47 (*)
    │   │   │           └── unicode-ident v1.0.26
    │   │   ├── thiserror v2.0.21
    │   │   │   └── thiserror-impl v2.0.21 (proc-macro)
    │   │   │       ├── proc-macro2 v1.0.107 (*)
    │   │   │       ├── quote v1.0.47 (*)
    │   │   │       └── syn v3.0.6 (*)
    │   │   ├── unsigned-varint v0.8.0
    │   │   └── zeroize v1.9.0
    │   │       └── zeroize_derive v1.5.0 (proc-macro)
    │   │           ├── proc-macro2 v1.0.107 (*)
    │   │           ├── quote v1.0.47 (*)
    │   │           └── syn v2.0.119
    │   │               ├── proc-macro2 v1.0.107 (*)
    │   │               ├── quote v1.0.47 (*)
    │   │               └── unicode-ident v1.0.26
    │   ├── base58 v0.2.0
    │   ├── base64 v0.23.1
    │   ├── ed25519-dalek v3.0.0
    │   │   ├── curve25519-dalek v5.0.0
    │   │   │   ├── cfg-if v1.0.5
    │   │   │   ├── cpufeatures v0.3.1
    │   │   │   ├── curve25519-dalek-derive v0.1.1 (proc-macro)
    │   │   │   │   ├── proc-macro2 v1.0.107 (*)
    │   │   │   │   ├── quote v1.0.47 (*)
    │   │   │   │   └── syn v2.0.119 (*)
    │   │   │   ├── digest v0.11.3
    │   │   │   │   ├── block-buffer v0.12.1
    │   │   │   │   │   └── hybrid-array v0.4.15
    │   │   │   │   │       ├── subtle v2.6.1
    │   │   │   │   │       ├── typenum v1.20.1
    │   │   │   │   │       └── zeroize v1.9.0 (*)
    │   │   │   │   ├── const-oid v0.10.2
    │   │   │   │   ├── crypto-common v0.2.2
    │   │   │   │   │   ├── getrandom v0.4.3
    │   │   │   │   │   │   ├── cfg-if v1.0.5
    │   │   │   │   │   │   ├── libc v0.2.189
    │   │   │   │   │   │   └── rand_core v0.10.1
    │   │   │   │   │   ├── hybrid-array v0.4.15 (*)
    │   │   │   │   │   └── rand_core v0.10.1
    │   │   │   │   └── ctutils v0.4.2
    │   │   │   │       ├── cmov v0.5.4
    │   │   │   │       └── subtle v2.6.1
    │   │   │   ├── rand_core v0.10.1
    │   │   │   ├── subtle v2.6.1
    │   │   │   └── zeroize v1.9.0 (*)
    │   │   ├── ed25519 v3.0.0
    │   │   │   └── signature v3.0.0
    │   │   │       ├── digest v0.11.3 (*)
    │   │   │       └── rand_core v0.10.1
    │   │   ├── rand_core v0.10.1
    │   │   ├── sha2 v0.11.0
    │   │   │   ├── cfg-if v1.0.5
    │   │   │   ├── cpufeatures v0.3.1
    │   │   │   └── digest v0.11.3 (*)
    │   │   ├── signature v3.0.0 (*)
    │   │   ├── subtle v2.6.1
    │   │   └── zeroize v1.9.0 (*)
    │   ├── k256 v0.14.0
    │   │   ├── cpubits v0.1.1
    │   │   ├── ecdsa v0.17.0
    │   │   │   ├── der v0.8.2
    │   │   │   │   ├── const-oid v0.10.2
    │   │   │   │   ├── pem-rfc7468 v1.0.0
    │   │   │   │   │   └── base64ct v1.8.3
    │   │   │   │   └── zeroize v1.9.0 (*)
    │   │   │   ├── digest v0.11.3 (*)
    │   │   │   ├── elliptic-curve v0.14.1
    │   │   │   │   ├── base16ct v1.0.0
    │   │   │   │   ├── crypto-bigint v0.7.5
    │   │   │   │   │   ├── cpubits v0.1.1
    │   │   │   │   │   ├── ctutils v0.4.2 (*)
    │   │   │   │   │   ├── getrandom v0.4.3 (*)
    │   │   │   │   │   ├── hybrid-array v0.4.15 (*)
    │   │   │   │   │   ├── num-traits v0.2.19
    │   │   │   │   │   ├── rand_core v0.10.1
    │   │   │   │   │   ├── subtle v2.6.1
    │   │   │   │   │   └── zeroize v1.9.0 (*)
    │   │   │   │   ├── crypto-common v0.2.2 (*)
    │   │   │   │   ├── digest v0.11.3 (*)
    │   │   │   │   ├── ff v0.14.0
    │   │   │   │   │   ├── rand_core v0.10.1
    │   │   │   │   │   └── subtle v2.6.1
    │   │   │   │   ├── group v0.14.0
    │   │   │   │   │   ├── ff v0.14.0 (*)
    │   │   │   │   │   ├── rand_core v0.10.1
    │   │   │   │   │   └── subtle v2.6.1
    │   │   │   │   ├── hkdf v0.13.0
    │   │   │   │   │   └── hmac v0.13.0
    │   │   │   │   │       └── digest v0.11.3 (*)
    │   │   │   │   ├── hybrid-array v0.4.15 (*)
    │   │   │   │   ├── pem-rfc7468 v1.0.0 (*)
    │   │   │   │   ├── pkcs8 v0.11.0
    │   │   │   │   │   ├── der v0.8.2 (*)
    │   │   │   │   │   └── spki v0.8.0
    │   │   │   │   │       └── der v0.8.2 (*)
    │   │   │   │   ├── rand_core v0.10.1
    │   │   │   │   ├── sec1 v0.8.1
    │   │   │   │   │   ├── base16ct v1.0.0
    │   │   │   │   │   ├── ctutils v0.4.2 (*)
    │   │   │   │   │   ├── der v0.8.2 (*)
    │   │   │   │   │   ├── hybrid-array v0.4.15 (*)
    │   │   │   │   │   ├── subtle v2.6.1
    │   │   │   │   │   └── zeroize v1.9.0 (*)
    │   │   │   │   ├── subtle v2.6.1
    │   │   │   │   └── zeroize v1.9.0 (*)
    │   │   │   ├── rfc6979 v0.6.0
    │   │   │   │   ├── crypto-bigint v0.7.5 (*)
    │   │   │   │   └── hmac v0.13.0 (*)
    │   │   │   ├── signature v3.0.0 (*)
    │   │   │   ├── spki v0.8.0 (*)
    │   │   │   └── zeroize v1.9.0 (*)
    │   │   ├── elliptic-curve v0.14.1 (*)
    │   │   ├── primeorder v0.14.0
    │   │   │   ├── elliptic-curve v0.14.1 (*)
    │   │   │   ├── primefield v0.14.0
    │   │   │   │   ├── crypto-bigint v0.7.5 (*)
    │   │   │   │   ├── crypto-common v0.2.2 (*)
    │   │   │   │   ├── ff v0.14.0 (*)
    │   │   │   │   ├── rand_core v0.10.1
    │   │   │   │   ├── subtle v2.6.1
    │   │   │   │   └── zeroize v1.9.0 (*)
    │   │   │   └── wnaf v0.14.1
    │   │   │       ├── ff v0.14.0 (*)
    │   │   │       ├── group v0.14.0 (*)
    │   │   │       ├── hybrid-array v0.4.15 (*)
    │   │   │       └── primefield v0.14.0 (*)
    │   │   ├── sha2 v0.11.0 (*)
    │   │   ├── signature v3.0.0 (*)
    │   │   └── wnaf v0.14.1 (*)
    │   ├── multibase v0.9.3
    │   │   ├── base-x v0.2.11
    │   │   ├── base256emoji v1.0.2
    │   │   │   ├── const-str v0.4.3
    │   │   │   └── match-lookup v0.1.3 (proc-macro)
    │   │   │       ├── proc-macro2 v1.0.107 (*)
    │   │   │       ├── quote v1.0.47 (*)
    │   │   │       └── syn v2.0.119 (*)
    │   │   ├── base45 v3.2.0
    │   │   ├── data-encoding v2.11.1
    │   │   └── data-encoding-macro v0.1.21
    │   │       ├── data-encoding v2.11.1
    │   │       └── data-encoding-macro-internal v0.1.19 (proc-macro)
    │   │           ├── data-encoding v2.11.1
    │   │           └── syn v3.0.6 (*)
    │   ├── p256 v0.14.0
    │   │   ├── ecdsa v0.17.0 (*)
    │   │   ├── elliptic-curve v0.14.1 (*)
    │   │   ├── primefield v0.14.0 (*)
    │   │   ├── primeorder v0.14.0 (*)
    │   │   └── sha2 v0.11.0 (*)
    │   ├── p384 v0.14.0
    │   │   ├── ecdsa v0.17.0 (*)
    │   │   ├── elliptic-curve v0.14.1 (*)
    │   │   ├── primefield v0.14.0 (*)
    │   │   ├── primeorder v0.14.0 (*)
    │   │   └── sha2 v0.11.0 (*)
    │   ├── p521 v0.14.0
    │   │   ├── base16ct v1.0.0
    │   │   ├── ecdsa v0.17.0 (*)
    │   │   ├── elliptic-curve v0.14.1 (*)
    │   │   ├── primefield v0.14.0 (*)
    │   │   ├── primeorder v0.14.0 (*)
    │   │   └── sha2 v0.11.0 (*)
    │   ├── rand v0.10.3
    │   │   ├── chacha20 v0.10.2
    │   │   │   ├── cfg-if v1.0.5
    │   │   │   ├── cpufeatures v0.3.1
    │   │   │   └── rand_core v0.10.1
    │   │   ├── getrandom v0.4.3 (*)
    │   │   └── rand_core v0.10.1
    │   ├── rand_core v0.6.4
    │   │   └── getrandom v0.2.17
    │   │       ├── cfg-if v1.0.5
    │   │       └── libc v0.2.189
    │   ├── serde v1.0.229 (*)
    │   ├── serde_json v1.0.151
    │   │   ├── itoa v1.0.18
    │   │   ├── memchr v2.8.3
    │   │   ├── serde_core v1.0.229
    │   │   └── zmij v1.0.23
    │   ├── sha2 v0.11.0 (*)
    │   ├── thiserror v2.0.21 (*)
    │   ├── x25519-dalek v3.0.0
    │   │   ├── curve25519-dalek v5.0.0 (*)
    │   │   ├── rand_core v0.10.1
    │   │   └── zeroize v1.9.0 (*)
    │   └── zeroize v1.9.0 (*)
    ├── affinidi-encoding v0.1.6 (*)
    ├── base64 v0.23.1
    ├── serde v1.0.229 (*)
    ├── serde_json v1.0.151 (*)
    ├── thiserror v2.0.21 (*)
    ├── url v2.5.8
    │   ├── form_urlencoded v1.2.2
    │   │   └── percent-encoding v2.3.2
    │   ├── idna v1.1.0
    │   │   ├── idna_adapter v1.2.2
    │   │   │   ├── icu_normalizer v2.3.0
    │   │   │   │   ├── icu_collections v2.3.0
    │   │   │   │   │   ├── displaydoc v0.2.7 (proc-macro)
    │   │   │   │   │   │   ├── proc-macro2 v1.0.107 (*)
    │   │   │   │   │   │   ├── quote v1.0.47 (*)
    │   │   │   │   │   │   └── syn v3.0.6 (*)
    │   │   │   │   │   ├── potential_utf v0.1.6
    │   │   │   │   │   │   └── zerovec v0.11.8
    │   │   │   │   │   │       ├── yoke v0.8.3
    │   │   │   │   │   │       │   ├── stable_deref_trait v1.2.1
    │   │   │   │   │   │       │   ├── yoke-derive v0.8.3 (proc-macro)
    │   │   │   │   │   │       │   │   ├── proc-macro2 v1.0.107 (*)
    │   │   │   │   │   │       │   │   ├── quote v1.0.47 (*)
    │   │   │   │   │   │       │   │   ├── syn v3.0.6 (*)
    │   │   │   │   │   │       │   │   └── synstructure v0.14.0
    │   │   │   │   │   │       │   │       ├── proc-macro2 v1.0.107 (*)
    │   │   │   │   │   │       │   │       ├── quote v1.0.47 (*)
    │   │   │   │   │   │       │   │       └── syn v3.0.6 (*)
    │   │   │   │   │   │       │   └── zerofrom v0.1.8
    │   │   │   │   │   │       │       └── zerofrom-derive v0.1.8 (proc-macro)
    │   │   │   │   │   │       │           ├── proc-macro2 v1.0.107 (*)
    │   │   │   │   │   │       │           ├── quote v1.0.47 (*)
    │   │   │   │   │   │       │           ├── syn v3.0.6 (*)
    │   │   │   │   │   │       │           └── synstructure v0.14.0 (*)
    │   │   │   │   │   │       ├── zerofrom v0.1.8 (*)
    │   │   │   │   │   │       └── zerovec-derive v0.11.6 (proc-macro)
    │   │   │   │   │   │           ├── proc-macro2 v1.0.107 (*)
    │   │   │   │   │   │           ├── quote v1.0.47 (*)
    │   │   │   │   │   │           └── syn v3.0.6 (*)
    │   │   │   │   │   ├── utf8_iter v1.0.4
    │   │   │   │   │   ├── yoke v0.8.3 (*)
    │   │   │   │   │   ├── zerofrom v0.1.8 (*)
    │   │   │   │   │   └── zerovec v0.11.8 (*)
    │   │   │   │   ├── icu_normalizer_data v2.3.0
    │   │   │   │   ├── icu_provider v2.3.1
    │   │   │   │   │   ├── displaydoc v0.2.7 (proc-macro) (*)
    │   │   │   │   │   ├── icu_locale_core v2.3.0
    │   │   │   │   │   │   ├── displaydoc v0.2.7 (proc-macro) (*)
    │   │   │   │   │   │   ├── litemap v0.8.3
    │   │   │   │   │   │   ├── tinystr v0.8.4
    │   │   │   │   │   │   │   ├── displaydoc v0.2.7 (proc-macro) (*)
    │   │   │   │   │   │   │   └── zerovec v0.11.8 (*)
    │   │   │   │   │   │   ├── writeable v0.6.4
    │   │   │   │   │   │   └── zerovec v0.11.8 (*)
    │   │   │   │   │   ├── writeable v0.6.4
    │   │   │   │   │   ├── yoke v0.8.3 (*)
    │   │   │   │   │   ├── zerofrom v0.1.8 (*)
    │   │   │   │   │   ├── zerotrie v0.2.5
    │   │   │   │   │   │   ├── displaydoc v0.2.7 (proc-macro) (*)
    │   │   │   │   │   │   ├── yoke v0.8.3 (*)
    │   │   │   │   │   │   └── zerofrom v0.1.8 (*)
    │   │   │   │   │   └── zerovec v0.11.8 (*)
    │   │   │   │   ├── smallvec v1.16.2
    │   │   │   │   └── zerovec v0.11.8 (*)
    │   │   │   └── icu_properties v2.3.0
    │   │   │       ├── displaydoc v0.2.7 (proc-macro) (*)
    │   │   │       ├── icu_collections v2.3.0 (*)
    │   │   │       ├── icu_locale_core v2.3.0 (*)
    │   │   │       ├── icu_properties_data v2.3.0
    │   │   │       ├── icu_provider v2.3.1 (*)
    │   │   │       ├── zerotrie v0.2.5 (*)
    │   │   │       └── zerovec v0.11.8 (*)
    │   │   ├── smallvec v1.16.2
    │   │   └── utf8_iter v1.0.4
    │   ├── percent-encoding v2.3.2
    │   ├── serde v1.0.229 (*)
    │   └── serde_derive v1.0.229 (proc-macro) (*)
    ├── x25519-dalek v3.0.0 (*)
    └── zeroize v1.9.0 (*)
```

No crate anywhere in this tree has "resolver" in its name. The Affinidi DID
**resolver** crate is not a dependency of `affinidi-did-common` and was never
added to `backend/Cargo.toml`.

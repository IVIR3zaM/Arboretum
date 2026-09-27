# The `did:web` method

*Snapshot of the method specification as implemented by the platform. Based on the W3C CCG
did:web Method Specification and DID Core 1.0.*

## 1. Method name

The method name is `web`. A DID that uses this method MUST begin with the prefix `did:web:`.

## 2. Method-specific identifier

The method-specific identifier is a fully qualified domain name, optionally followed by a path,
with every `/` of the path replaced by `:`. The domain name is secured by a TLS/SSL certificate.

```
did-web-did        = "did:web:" domain-name *( ":" path-segment )
```

- The domain name MUST NOT include IP addresses.
- A port, if one is needed, MUST be percent-encoded: the `:` between host and port is written
  `%3A` so that it is not read as a path separator.
- Every path segment is percent-decoded before it is used.

## 3. Operations

### 3.1 Create

The controller creates a DID document and publishes it at the HTTPS URL the DID maps to
(section 3.2). The document's `id` MUST be the DID.

### 3.2 Read (resolve)

To resolve a `did:web` DID:

1. Remove the `did:web:` prefix.
2. Split the remainder on `:`. The first segment is the host; the remaining segments are the path.
3. Percent-decode each segment (this is how a port, `%3A`, is recovered).
4. If there are no path segments, append `/.well-known` as the path.
5. Append `/did.json`.
6. Prefix `https://`.
7. Perform an HTTPS `GET` on the resulting URL. The response body is the DID document.
8. The resolved document's `id` MUST equal the DID being resolved. If it does not, resolution
   fails.

| DID | Document URL |
|---|---|
| `did:web:w3c-ccg.github.io` | `https://w3c-ccg.github.io/.well-known/did.json` |
| `did:web:w3c-ccg.github.io:user:alice` | `https://w3c-ccg.github.io/user/alice/did.json` |
| `did:web:example.com%3A3000` | `https://example.com:3000/.well-known/did.json` |
| `did:web:example.com%3A3000:user:alice` | `https://example.com:3000/user/alice/did.json` |

Resolution is performed over HTTPS; a client MUST NOT fall back to plain HTTP. The HTTPS GET is the
only source of the DID document: the document is not derivable from the identifier.

### 3.3 Update

The controller updates the DID by replacing the document at its URL. Keys are added, rotated and
removed, and service endpoints changed, this way. There is no separate update message and no
history of earlier versions is exposed: the document currently served at the URL **is** the DID
document.

### 3.4 Deactivate

The controller deactivates the DID by removing the document from its URL. Resolution of a
deactivated DID fails.

## 4. Verifying with a `did:web` DID

A verifier checking a proof made by a `did:web` controller:

1. Resolves the DID (section 3.2) when it verifies the proof.
2. Dereferences the proof's `verificationMethod` in the resolved document.
3. Checks that the verification method is referenced by the verification relationship the proof
   claims — `assertionMethod` for a credential issuer's proof, `authentication` for a holder's.
4. Verifies the signature with that verification method's public key
   (`Multikey`, `publicKeyMultibase`, Ed25519 multicodec `0xed01`).

A key that no longer appears in the document served at the DID's URL is not a key of the DID. A
proof is valid only if it verifies against a verification method in the current document.

HTTP caching of the document is permitted within the `Cache-Control` lifetime the host returns.

## 5. Security and privacy considerations

- **DNS and TLS.** The security of `did:web` is that of the domain: whoever controls the domain
  and its certificate controls the DID.
- **Key rotation.** Controllers are expected to rotate keys. Because only the current document is
  authoritative, rotation takes effect for every verifier as soon as the new document is served.
- **No self-certification.** Unlike `did:key` and `did:peer`, the identifier carries no key
  material; nothing about a `did:web` document can be checked from the DID alone.
- **Successor methods.** `did:webvh` (did:web + verifiable history) adds a signed, hash-chained
  log of document versions for controllers that need a verifiable key-rotation history. It is not
  used on the platform.

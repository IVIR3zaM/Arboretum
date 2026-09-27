# Issuer DID document hosting

Issuers on the platform publish their `did:web` DID documents through the platform's document
bucket rather than their own web servers.

| Setting | Value |
|---|---|
| Bucket | `s3://issuer-did-documents-prod` (eu-west-1), versioning on |
| Distribution | CloudFront `E2T9QK4ZC1MX7B`, one alternate domain name per issuer host |
| Origin path | none — the object key is `<host>/<path>`, exactly the path part of the DID's HTTPS URL |
| Object for `did:web:<host>` | `<host>/.well-known/did.json` |
| Object for `did:web:<host>:<p1>:<p2>` | `<host>/<p1>/<p2>/did.json` |
| Content-Type | `application/did+json` |
| Cache-Control | `max-age=300` |
| Writers | the issuer console only (one IAM role per issuer, scoped to that issuer's host prefix) |

Issuers manage their keys and service endpoints in the issuer console. Adding, rotating or
retiring a key, or changing a service endpoint, writes a new version of the issuer's `did.json`
object and invalidates its path on the distribution. The previous version is retained in the
bucket's version history but is no longer served.

`hosted-dids/` is a copy of the bucket's current objects, laid out by object key.

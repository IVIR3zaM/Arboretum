# Reserved domain names in configuration

*Snapshot of the Platform Infrastructure standard PI-STD-014, "Domain names in service
configuration". Owner: Platform Infrastructure.*

## Rule

A domain name reserved for documentation or testing MUST NOT appear as a live endpoint in any
production configuration or code path. This covers every outbound call a service makes:
webhooks and callbacks, health and liveness probes, synthetic monitoring, and the targets of any
check whose result is reported as the state of a platform service.

## Reserved names

RFC 2606 §3 reserves the following second-level domain names for use in documentation and
examples:

| Name | Reserved by |
|---|---|
| `example.com` | RFC 2606 §3 |
| `example.net` | RFC 2606 §3 |
| `example.org` | RFC 2606 §3 |

These names are held by IANA. They resolve, and a server operated by IANA may answer requests
sent to them. They are not platform infrastructure: traffic sent to them leaves the platform, and
a response from one says nothing about the state of any platform service.

## What to use instead

| Need | Use |
|---|---|
| An endpoint in documentation or a sample payload | a reserved name — that is what they are for |
| A target for a probe or health check | an endpoint the platform operates, reached over the same path as the traffic it vouches for |
| An endpoint in an automated test | a stub the test controls, served in-process or on loopback |

## Enforcement

Configuration linting in the deploy pipeline rejects the names above in `deploy.yaml` files.

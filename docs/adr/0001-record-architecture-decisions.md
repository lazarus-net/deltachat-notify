# 0001 — Record architecture decisions
Date: 2025-10-16
Status: Accepted
Deciders: <team/roles>
Consulted: <names/roles>
Informed: <names/roles>
Tags: governance, documentation

## Context
We need a lightweight, versioned way to capture significant decisions and their rationale.

## Decision
Adopt Architecture Decision Records stored in `/docs/adr`, using the Nygard format and numbering scheme.

## Consequences
- Pros: discoverable history; rationale preserved; easy to diff/review.
- Cons: small overhead to write/curate.
- Tooling: allow (but don’t require) `adr-tools`/scripts.

## References
- Michael Nygard, “Documenting Architecture Decisions”. :contentReference[oaicite:6]{index=6}
- ADR organization site & templates. :contentReference[oaicite:7]{index=7}


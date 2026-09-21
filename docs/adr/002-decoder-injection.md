# ADR 002: Charset decoding is injectable

- Status: Accepted
- Date: 2026-09-21

## Context

Mail charset declarations are frequently wrong. A parser should retain the
decoded transfer bytes without depending on a particular charset detector.

## Decision

`Message#decoded` accepts an optional callable receiving bytes and the declared
charset. The standard-library fallback handles common Ruby encodings, while an
application may inject a stronger detector such as menkar.

## Consequences

Ukdah has no runtime dependency on the reader application or a charset gem.
Callers that need detection beyond Ruby's encodings must inject that policy.

# ADR 001: Parsing only, no transport

- Status: Accepted
- Date: 2026-09-21

## Context

Ukdah is the mail source's parsing boundary. Adding IMAP, POP, or SMTP would
turn a deterministic library into a network client with credentials, retry,
and security policy concerns.

## Decision

Ukdah parses RFC 5322, MIME, and mbox bytes only. Network transport and message
construction remain outside the gem.

## Consequences

The runtime stays small, dependency-free, and safe to use on untrusted files.
Applications must provide transport and persistence separately.

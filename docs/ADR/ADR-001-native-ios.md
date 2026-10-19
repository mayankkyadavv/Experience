# ADR-001: Native iOS app

- **Status:** Accepted (2026-10-18) · **Ledger:** D3, office-hours approach B

## Context
Capture has to cost about one tap, which means living in the iOS share sheet. Geofenced reminders and a smooth feed of embeds are core to the product. The founder chose native-first over an SMS-bot validation path.

## Decision
A SwiftUI app plus a share extension, both depending on a local Swift package, **`ExperienceCore`** (models, `Sourced<T>`, API client, outbox, auth, provenance types). The project is generated with XcodeGen. Minimum iOS version: the lowest that keeps the code simple, chosen in M1.

## Consequences
- iPhone only for now: no Android, which also limits a stranger cohort.
- The extension and app share an App Group and a keychain group.
- Logic lives in `ExperienceCore` so it's unit-testable without a simulator.

## Revisit when
Friends without iPhones block the expansion gate, or a web surface becomes necessary.

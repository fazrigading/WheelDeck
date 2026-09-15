## Summary

<!-- What message/enum/schema changed, and why? -->

Closes #<!-- issue number -->

> [!WARNING]
> Protocol is the single source of truth in `protocol/schema/`. Mobile and desktop must stay in sync.

## Schema Changes

<!-- List files changed under protocol/schema/ -->

- [ ] `protocol/schema/` updated
- [ ] Breaking change (old peers reject / misread new messages)
- [ ] Backward compatible (old peers ignore / default new fields)

## Compatibility

<!-- How do mismatched versions behave? What happens when only one side updates? -->

- Mobile handles old server messages:
- Desktop handles old client messages:
- Migration / rollout notes:

## Changes

### Mobile (Flutter)

-
-

### Desktop (.NET)

-
-

## Testing

- [ ] `flutter analyze` / `flutter test`
- [ ] `dotnet build desktop/WheelDeck.sln` / `dotnet test desktop/WheelDeck.sln`
- [ ] End-to-end: phone paired with desktop, messages verified over WebSocket
- [ ] Old-vs-new version interop checked (if breaking)

### Manual

- [ ] Tested on Windows
- [ ] Tested on Linux
- [ ] Tested on Android
- [ ] Tested on iOS (if applicable)

## Checklist

- [ ] Both sides (mobile + desktop) updated or explicit reason one side needs no change
- [ ] Docs updated (`docs/` — message format, enums)
- [ ] No new warnings introduced

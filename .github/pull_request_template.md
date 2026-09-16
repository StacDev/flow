## Summary

<!-- What changes, and why. Link the issue it closes: Closes #123 -->

## Screenshots

<!-- flow_ui is a UI library, so anything visual needs a picture. Delete this
     section only if the change renders nothing. -->

| Before | After |
| --- | --- |
|  |  |

## How this was verified

<!-- Which playground stages you exercised, on which platforms (and both
     themes, if the change touches colour). -->

## Checklist

- [ ] `dart run melos run analyze` is clean
- [ ] `dart run melos run format` applied
- [ ] Exercised in the playground — with a stage demo added or updated if this is a new component or variant
- [ ] Any new entry under `dependencies:` in `packages/flow_ui/pubspec.yaml` is flutter.dev-published, forces no configuration on hosts that never use the feature, and is argued in this PR
- [ ] Nothing model-facing — no prompts, schemas, or provider/network calls
- [ ] New public API is exported from `packages/flow_ui/lib/flow_ui.dart` and documented in `docs/` and the README table
- [ ] `packages/flow_ui/CHANGELOG.md` updated for user-facing changes, with breaking changes called out
- [ ] PR title follows conventional commits (`feat:`, `fix:`, `refactor:`, `docs:`, `chore:`)

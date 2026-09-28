# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

**flow_ui** is a chat/assistant UI component library for Flutter — the presentation layer for AI assistant interfaces. It is a plain Flutter package (no codegen) at `packages/flow_ui/`, inside a pub workspace driven by melos. Downstream packages depend on the public API exported from `lib/flow_ui.dart`, so treat it as a compatibility surface.

Two hard constraints shape everything here:

- **One dependency beyond flutter.dev, argued.** `dependencies:` in `pubspec.yaml` holds the Flutter SDK, Flutter's own first-party packages — `material_ui` (Material's home since Flutter 3.47) and its transitive set, all published by flutter.dev — plus `file_selector` (flutter.dev), the plugin behind the composer's attach button. Nothing else, and adding one is a decision rather than a convenience: it must not force configuration on hosts that never touch the feature (this is why `file_selector` and not `image_picker`, which writes a permission, a FileProvider and a Play-services entry into every host's Android manifest), and the PR has to argue it. What the one we have does ask for is documented: the picker needs macOS `com.apple.security.files.user-selected.read-only`. Dev dependencies (`flutter_test`, `flutter_lints`) are fine.
- **The typefaces ship, they are not fetched.** Google Sans and Google Sans Code live in `packages/flow_ui/fonts/` under the SIL Open Font License, declared under `flutter: fonts:` with every cut (sans 400–700, mono 300–800, each upright and italic) and addressed as `package: 'flow_ui'`. Google Sans is a Latin subset — the full cuts are ~1.95 MB each — rebuilt by `packages/flow_ui/tool/subset_fonts.sh`; the scripts it drops fall back to the platform face. Nothing reaches the network for a glyph, so hosts need no INTERNET permission and no macOS network entitlement.
- **Nothing model-facing.** Components render state passed in and report intent out through callbacks. No prompts, schemas, provider/network calls, or any LLM awareness — that belongs to the layers built on top.

The theme, the conversation components (message, thread, streaming text, actions, loading), the composer and its menus, attachments with their preview, suggestions, and the chat surface are implemented; the roadmap below tracks the rest. Message content is modeled as typed parts (`lib/src/models/`) — sealed `FlowMessagePart` subtypes rendered by `FlowMessage`, with `FlowCustomPart` + `FlowCustomPartBuilder` as the extension seam for host-injected content.

## Layout

- Root `pubspec.yaml` is the pub workspace (members under `workspace:`) with the melos scripts; root `analysis_options.yaml` (very_good_analysis) governs `tool/` and the SDK package only.
- `packages/flow_ui/` — the published package: `lib/`, `example/` (the README's chat screen against Gemini), `assets/`, `fonts/` (the bundled typefaces and their OFL texts), `tool/` (`subset_fonts.sh`, not published), its own flutter_lints `analysis_options.yaml` and `.pubignore`.
- `packages/stacflow/` — the StacFlow SDK package (see "SDK package"), with `example/` (the README's chat screen against Gemini; flutter_lints like the flow_ui example).
- `playground/` — the Flow UI Playground: a full Flutter app and workspace member depending on `flow_ui: ^0.4.0`. Use it to demo and manually exercise components (every component has a stage demo, with variant pills and code snippets).
- `docs/` — the Astro site behind flowui.stac.dev. `contracts/` — the SDK wire contract.

## Commands

**Don't write tests for now.** `packages/flow_ui` has no `test/` yet: the component surface is still being reshaped design-first, so tests written now would mostly encode values about to change. Verify a change with `flutter analyze` and by exercising it in the `playground/` app, not by adding a test file. If something seems to genuinely need one, say so and let the user decide.

**Don't write comments unless asked.** No doc comments, file headers or inline explanations in new or edited code; the code and the commit message carry the intent. The one exception is a comment a lint requires (for example `document_ignores` above an `// ignore`), kept to one line. Public API dartdoc is written only when the user asks for it.

From the repo root:

```bash
flutter pub get                    # resolves the whole workspace
dart run melos run analyze         # dart analyze --fatal-infos in every member
dart run melos run format
dart run melos run test            # SDK package tests; flow_ui has none yet
cd packages/flow_ui && flutter analyze && flutter pub publish --dry-run
```

Playground app:

```bash
cd playground
flutter pub get
flutter run -d chrome    # or any device
```

## SDK package

`packages/stacflow` is the StacFlow SDK: `StacFlowChat` (the controller) and `StacFlowChatView` on flow_ui, wired to Gemini, OpenAI and Claude with the developer's own key. One entrypoint, `package:stacflow/stacflow.dart`, which also re-exports flow_ui. Layout: `src/chat` (controller, state, view, and the flow_ui-to-wire reduction in `wire_history.dart`), `src/transport` (the `TurnTransport` seam, `TurnRequest` and the wire types, ids, the SSE parser; pure Dart), `src/providers` (the interface, the shared HTTP runner, one adapter per provider; pure Dart), `src/tools` (`Tool`, the call records and `runToolLoop`, the client-side tool loop shared by the controller and the smoke script; pure Dart). Rules:

- `stacflow` depends on `flow_ui`, never the reverse (CI grep).
- Adapters emit the `SseEvent` union: `start` first, one `done` last, `seq` from 0. The runner in `turn_runner.dart` owns HTTP, abort, timeouts, key scrubbing and the tool-call bookkeeping (ids, argument buffering, the upgrade of `complete()` to `done{awaiting_client_tools}`); an adapter only declares `TurnRequest.tools`, maps frames, encodes the wire tool parts in history and replays its own raw content within a turn where the provider requires it (Gemini signatures and ids, Claude thinking blocks).
- The loop in `tool_loop.dart` owns dispatch, approval, timeouts, abort and the continuation segments; the controller only renders blocks into parts, keeps `ChatState.toolCalls`, and answers confirmations. `contracts/` is unchanged by tools: provider call ids ride inside the `tc_` ids.
- The API key is a private field set on exactly one header, and never appears in URLs, logs, `toString` or error text.
- No tests for now. Verify with `dart analyze --fatal-infos`, the smoke script (`cd packages/stacflow && dart run --define=PROVIDER=gemini --define=GEMINI_API_KEY=... tool/smoke.dart`, also `anthropic` and `openai`; `--define=ABORT_AFTER_FIRST_DELTA=true` and `--define=IMAGE=path.png` exercise abort and image input; `--define=TOOLS=true` registers a `get_time` tool and runs the loop, with `TOOL_PERMISSION=destructive` and `DECLINE=true` for the approval paths), and the example app (`cd packages/stacflow/example && flutter run` with the key in `lib/env.dart`, copied from `lib/env.example.dart` and gitignored; the `stacflow-example` entry in `.claude/launch.json` serves it on port 8124). Keep the example the runnable form of the README quickstart, against Gemini only, with the `set_theme` tool as its one tool.

`contracts/` is the wire contract (SSE events, error codes): the specification the SDK is held to, kept as prose and JSON Schema. Nothing generates code from it. The Dart types live beside the rest of the transport layer in `packages/stacflow/lib/src/transport/sse_events.dart` and `error_codes.dart`, hand-written and owned like any other source file, so an edit under `contracts/` means editing those two files in the same commit.

## Releases

Per-package tags: `flow_ui-v<version>` publishes `packages/flow_ui` and deploys the docs site (`.github/workflows/publish.yml`). Before tagging, bump `version:` in `packages/flow_ui/pubspec.yaml`, the `flow_ui:` constraint in `packages/flow_ui/example`, `playground` and `packages/stacflow` (pre-1.0 caret ranges), and `CHANGELOG.md`. `stacflow-v<version>` publishes `packages/stacflow` the same way; before tagging, bump `version:` in `packages/stacflow/pubspec.yaml`, the `stacflow:` constraint in `packages/stacflow/example`, and its `CHANGELOG.md`. The pana gate wants a perfect score from both packages.

## Commits

Commit messages are conventional commits with a brief summary line:
`feat: <brief-commit-message>` — `fix:`, `refactor:`, `docs:`, `chore:` as
appropriate. Add a body only when a decision genuinely needs recording, and
never any AI attribution.

## Component roadmap

Status legend: ⬜ Todo · ✅ Done

### Theme (build first)

`ThemeExtension`-based design tokens for **colors and typography**; every component consumes these two token sets (no hardcoded colors or text styles). Spacing and corner radii are deliberately *not* tokens: following Material's structure, each component bakes its own metrics from the Figma file as private spec constants and exposes per-widget overrides (`padding:`, `borderRadius:`) where hosts retheme.

Values come from the Flow UI Figma file. Role names follow Material 3's `ColorScheme` so a host can map an existing scheme across; Flow adds a third ink level (`onSurface` / `onSurfaceVariant` 75% / `onSurfaceMuted` 50%), `success` / `warning` groups beside `error`, and a `shadow` role (the ink at 2%, alpha included) that the composer, the menu card, attachment tiles and the jump disc draw their shadows with. Three rules hold the palette together: the ink ramp, the outlines (`outline` the faint hairline, `outlineVariant` the firm one) and the container ladder `Lowest → Highest` are **translucent** ink washes, so the same label, hairline and fill read correctly on the page and on a raised card; accent containers are their accent at 8% (statuses 6%) with the accent as the `on` colour; and the grounds — `surface` and `surfaceBright` — are **opaque**. The raised card — the composer, menus, sheets — sits on `surfaceBright` (white / `#1E1E1E`), the one surface that lifts off the page in both themes.

| # | Component | Notes | Status |
|---|-----------|-------|--------|
| 1 | Design tokens | colors, typography; metrics are per-component spec values | ✅ |
| 2 | Light/dark themes | | ✅ |

### Basic elements

| # | Component | Variants / notes | Status |
|---|-----------|------------------|--------|
| 3 | Avatar | default, with icon, group, group count, group icon | ⬜ |
| 4 | Button | primary, secondary, outline, text, icon, destructive | ⬜ |
| 5 | Text | | ⬜ |
| 6 | Chip | | ⬜ |
| 7 | Badge | | ⬜ |

### AI elements

| # | Component | Variants / notes | Status |
|---|-----------|------------------|--------|
| 8 | Message & Thread | ink-wash user bubble; plain assistant | ✅ |
| 9 | Thread List | host-labeled sections; unread dot, pinned glyph, leading icon slot; single selection by id | ✅ |
| 10 | Message actions | | ✅ |
| 11 | Streaming text | | ✅ |
| 12 | Message composer | full card; compact single-row pill that opens into the card as the draft grows; expands to fill a fixed height | ✅ |
| 13 | Model selector | effort & overflow submenus; sheet on phones | ✅ |
| 14 | Menu | icon-trigger menu: groups, submenus, toggles; sheet on phones | ✅ |
| 15 | Attachments | images and files, type pill; built-in picker and web file drop; videos pending | ✅ |
| 16 | Preview | full-screen image viewer: zoom, paging | ✅ |
| 17 | Tool | pending, running, complete, error; morphing status mark; collapsible input/output blocks; parts render in a thread | ✅ |
| 18 | Suggestion & Suggestion Group | plain & outlined rows; scroll, wrap, column | ✅ |
| 19 | Confirmation | pending, approved, rejected; approve/reject buttons; parts render in a thread | ✅ |
| 20 | Error state | failure card + retry pill; failed assistant turns render it automatically | ✅ |
| 21 | Code block | built-in synchronous highlighter; languages host-extensible | ✅ |
| 22 | Thinking indicator | turning, breathing asterisk + shimmer label; active & settled | ✅ |
| 23 | Shimmer | text only; sweeping highlight, static when settled | ✅ |
| 24 | Pill | removable tool/mode pill for the composer's action row; label auto-drops on phones | ✅ |
| 25 | Markdown | built-in parser + renderer; assistant text parts render it by default; fences compose Code block; tables, links, streaming reveal | ✅ |

### Surfaces

| # | Component | Variants / notes | Status |
|---|-----------|------------------|--------|
| 26 | Chat View | centred 760 rail; zero state (greeting, lifted composer, starters); jump to latest | ✅ |
| 27 | SidePanel | | ⬜ |
| 28 | Modal | | ⬜ |
| 29 | Toast | floating notice: icon, message, cross on a frosted card; showFlowToast floats it in the nearest Overlay, stacked, auto-dismissing, hover-paused, with a handle to dismiss | ✅ |

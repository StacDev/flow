# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

## What this is

**flow_ui** is a chat/assistant UI component library for Flutter — the presentation layer for AI assistant interfaces. It is a plain Flutter package (no codegen, no melos). Downstream packages depend on the public API exported from `lib/flow_ui.dart`, so treat it as a compatibility surface.

Two hard constraints shape everything here:

- **Two dependencies beyond flutter.dev, each argued.** `dependencies:` in `pubspec.yaml` holds the Flutter SDK, Flutter's own first-party packages — `material_ui` (Material's home since Flutter 3.47) and its transitive set, all published by flutter.dev — plus `file_selector` (flutter.dev), the plugin behind the composer's attach button, and `google_fonts` (material.io), which fetches Google Sans and Google Sans Code at runtime. No font files ship. Nothing else, and adding one is a decision rather than a convenience: it must not force configuration on hosts that never touch the feature (this is why `file_selector` and not `image_picker`, which writes a permission, a FileProvider and a Play-services entry into every host's Android manifest), and the PR has to argue it. What the two we have do ask for is documented: the fonts need `android.permission.INTERNET` and macOS `com.apple.security.network.client`; the picker needs macOS `com.apple.security.files.user-selected.read-only`. Dev dependencies (`flutter_test`, `flutter_lints`) are fine.
- **Nothing model-facing.** Components render state passed in and report intent out through callbacks. No prompts, schemas, provider/network calls, or any LLM awareness — that belongs to the layers built on top.

The theme, the conversation components (message, thread, streaming text, actions, loading), the composer and its menus, attachments with their preview, suggestions, and the chat surface are implemented; the roadmap below tracks the rest. Message content is modeled as typed parts (`lib/src/models/`) — sealed `FlowMessagePart` subtypes rendered by `FlowMessage`, with `FlowCustomPart` + `FlowCustomPartBuilder` as the extension seam for host-injected content.

## Layout

- Package at the repo root: `lib/`, `test/`, `pubspec.yaml`.
- `playground/` — the Flow UI Playground: a full Flutter app depending on the package via `path: ../`. Use it to demo and manually exercise components (every component has a stage demo, with variant pills and code snippets).

## Commands

From the repo root:

```bash
flutter test                                  # all tests
flutter test test/some_widget_test.dart       # single file
flutter test --plain-name "some test name"    # single test by name
flutter analyze
dart format .
```

Playground app:

```bash
cd playground
flutter pub get
flutter run -d chrome    # or any device
```

## Commits

Commit messages are conventional commits with a brief summary line:
`feat: <brief-commit-message>` — `fix:`, `refactor:`, `docs:`, `chore:` as
appropriate. Add a body only when a decision genuinely needs recording, and
never any AI attribution.

## Component roadmap

Status legend: ⬜ Todo · ✅ Done

### Theme (build first)

`ThemeExtension`-based design tokens for **colors and typography**; every component consumes these two token sets (no hardcoded colors or text styles). Spacing and corner radii are deliberately *not* tokens: following Material's structure, each component bakes its own metrics from the Figma file as private spec constants and exposes per-widget overrides (`padding:`, `borderRadius:`) where hosts retheme.

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
| 12 | Message composer | | ✅ |
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

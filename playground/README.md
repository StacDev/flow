# Flow UI Playground

The workbench for [flow_ui](../packages/flow_ui/): every component on a stage, with variant
pills and the code that renders them.

```bash
flutter pub get
flutter run -d chrome    # or any device
```

## URLs

Two contracts share one app.

**Components are paths.** `/playground/composer`, `/playground/full-chat` —
one address per `PlaygroundItem`, its `slug` (the enum name in kebab-case).
Linkable, bookmarkable, and walked by the browser's back button. Everything
else on screen — the variant pills, the theme, the device frame — is a
workbench setting that travels with the person, not the link, so it stays
out of the URL.

**Embeds are a query.** The docs site iframes single demos chrome-less:

```
/playground/index.html?embed=<slug>&variant=<id>&theme=<light|dark>
```

`main` branches on `?embed=` before the app is built, so embeds never touch
the router. An unknown `embed` renders "Unknown demo" rather than crashing
inside somebody's docs page; an unknown `variant` falls back to the first.

Path URLs need a rewrite on static hosting: **`docs/public/_redirects`** maps
`/playground/*` to `/playground/index.html`, and the dev-server equivalent
lives in `docs/astro.config.mjs`. Delete either and deep links start
serving the docs' 404. The build also depends on `--base-href /playground/`
(`docs/scripts/build-playground.sh`) to re-root assets from a component
path.

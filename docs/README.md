# flow_ui docs

The documentation site for [flow_ui](https://github.com/StacDev/flow_ui),
built with [Astro Starlight](https://starlight.astro.build).

```bash
npm install
npm run dev      # http://localhost:4321
npm run build    # static site in dist/
```

Google Sans loads from Google Fonts via the `<link>` in `astro.config.mjs`,
for this site's own chrome — the package bundles its own copy. Brand colors in
`src/styles/theme.css` mirror the package's design tokens in
`packages/flow_ui/lib/src/theme/flow_colors.dart`.

`npm run playground` builds the repo's `playground/` Flutter app for the
web into `public/playground/` — served at `/playground/<component>` (path
URLs, one per component) and embedded on component pages as live demos via
`src/components/FlowDemo.astro`
(`/playground/index.html?embed=<demo>&variant=<v>&theme=<light|dark>`).
`npm run build:site` chains playground + docs into one `dist/`.

Those component paths are routes inside the app, not files, so they need a
rewrite: `public/_redirects` sends `/playground/*` to
`/playground/index.html` on Cloudflare Pages, and the `playground-dev-index`
integration in `astro.config.mjs` does the same for `npm run dev`. Removing
either makes deep links serve the 404 page.

Deploys to Cloudflare Pages from `.github/workflows/publish.yml` — every
release tag ships the site (playground included) alongside the pub.dev
publish, and `workflow_dispatch` redeploys it on its own.

Planned: `dart doc` output under `public/api/`.

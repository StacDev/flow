// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

/** Dev-only: serve /playground/ and its component routes from
 * public/playground/index.html. Real static hosts resolve directory
 * indexes themselves, and the deploy rewrites the component paths through
 * public/_redirects; Astro's dev server does neither. */
const playgroundDevIndex = {
	name: 'playground-dev-index',
	hooks: {
		/** @param {{ server: import('vite').ViteDevServer }} ctx */
		'astro:server:setup'({ server }) {
			server.middlewares.use((req, _res, next) => {
				if (req.url === '/playground' || req.url === '/playground/') {
					req.url = '/playground/index.html';
				} else if (req.url?.startsWith('/playground/?')) {
					req.url = req.url.replace('/playground/?', '/playground/index.html?');
				} else if (/^\/playground\/[^.?]+(\?|$)/.test(req.url ?? '')) {
					// A component path like /playground/composer. Extensionless
					// only, so main.dart.js, canvaskit/ and assets/ pass through.
					req.url = req.url.replace(/^\/playground\/[^?]*/, '/playground/index.html');
				}
				next();
			});
		},
	},
};

// https://astro.build/config
export default defineConfig({
	site: 'https://flowui.stac.dev',
	// FlowChatScreen became FlowChatView in 0.2.0; keep the old page URL alive.
	redirects: {
		'/components/chat-screen': '/components/chat-view',
	},
	integrations: [
		playgroundDevIndex,
		starlight({
			title: 'Flow UI',
			description:
				'Flow UI is an open-source Flutter UI library to build production-grade Chat & AI assistant interfaces.',
			customCss: ['./src/styles/theme.css'],
			logo: { src: './src/assets/flow-ui-logo.svg', alt: '' },
			head: [
				// Google Sans from Google Fonts — the same source the package fetches at runtime.
				{ tag: 'link', attrs: { rel: 'preconnect', href: 'https://fonts.googleapis.com' } },
				{
					tag: 'link',
					attrs: { rel: 'preconnect', href: 'https://fonts.gstatic.com', crossorigin: true },
				},
				{
					tag: 'link',
					attrs: {
						rel: 'stylesheet',
						href: 'https://fonts.googleapis.com/css2?family=Google+Sans:wght@400;500;600;700&display=swap',
					},
				},
				// Social-preview image on every page — Starlight emits the rest
				// of the OG/Twitter tags; the image is ours to provide.
				{
					tag: 'meta',
					attrs: { property: 'og:image', content: 'https://flowui.stac.dev/og.png' },
				},
				{ tag: 'meta', attrs: { property: 'og:image:width', content: '1200' } },
				{ tag: 'meta', attrs: { property: 'og:image:height', content: '630' } },
				{
					tag: 'meta',
					attrs: {
						property: 'og:image:alt',
						content: 'Flow UI — Flutter UI library for AI chat interfaces',
					},
				},
				{
					tag: 'meta',
					attrs: { name: 'twitter:image', content: 'https://flowui.stac.dev/og.png' },
				},
			],
			components: {
				// Mirrors each page's og:title/description into the twitter: pair.
				Head: './src/components/Head.astro',
				PageTitle: './src/components/PageTitle.astro',
				ThemeSelect: './src/components/ThemeSelect.astro',
				SiteTitle: './src/components/SiteTitle.astro',
				SocialIcons: './src/components/SocialIcons.astro',
				// Stock provider with the auto fallback flipped to light for
				// browsers that don't support prefers-color-scheme.
				ThemeProvider: './src/components/ThemeProvider.astro',
			},
			expressiveCode: {
				styleOverrides: {
					borderRadius: '0.75rem',
					borderColor: 'var(--sl-color-hairline-light)',
					codeBackground: 'var(--flow-card)',
					codeFontSize: '0.8125rem',
					frames: {
						shadowColor: 'transparent',
						editorTabBarBackground: 'var(--flow-panel)',
						editorTabBarBorderBottomColor: 'var(--sl-color-hairline-light)',
						editorActiveTabBackground: 'transparent',
						editorActiveTabForeground: 'var(--sl-color-gray-2)',
						editorActiveTabIndicatorTopColor: 'transparent',
						editorActiveTabIndicatorBottomColor: 'var(--sl-color-accent)',
						editorBackground: 'var(--flow-card)',
						terminalBackground: 'var(--flow-card)',
						terminalTitlebarBackground: 'var(--flow-panel)',
						terminalTitlebarBorderBottomColor: 'var(--sl-color-hairline-light)',
						terminalTitlebarForeground: 'var(--sl-color-gray-3)',
					},
				},
			},
			social: [
				{
					icon: 'seti:dart',
					label: 'pub.dev',
					href: 'https://pub.dev/packages/flow_ui',
				},
				{
					icon: 'github',
					label: 'GitHub',
					href: 'https://github.com/StacDev/flow_ui',
				},
				{
					icon: 'x.com',
					label: 'X',
					href: 'https://x.com/stac_dev',
				},
				{
					icon: 'discord',
					label: 'Discord',
					href: 'https://discord.gg/PDFX9Ndsx',
				},
			],
			editLink: {
				baseUrl: 'https://github.com/StacDev/flow_ui/edit/main/docs/',
			},
			sidebar: [
				{
					label: 'Start here',
					items: ['getting-started', 'theming'],
				},
				{
					label: 'Components',
					items: [{ autogenerate: { directory: 'components' } }],
				},
				{ label: 'Roadmap', slug: 'roadmap' },
			],
		}),
	],
});

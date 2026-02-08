// @ts-check
const {themes} = require('prism-react-renderer');

/** @type {import('@docusaurus/types').Config} */
const config = {
  title: 'LEVERAGED',
  tagline: 'Leveraged Yield Farming with up to 5x Leverage',
  favicon: 'img/favicon.ico',

  url: 'https://docs.leveraged.finance',
  baseUrl: '/',

  organizationName: 'leveraged-finance',
  projectName: 'leveraged',

  onBrokenLinks: 'warn',
  onBrokenMarkdownLinks: 'warn',

  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

  presets: [
    [
      'classic',
      /** @type {import('@docusaurus/preset-classic').Options} */
      ({
        docs: {
          routeBasePath: '/',
          sidebarPath: './sidebars.js',
          editUrl: 'https://github.com/leveraged-finance/leveraged/tree/main/docs-site/',
        },
        blog: false,
        theme: {
          customCss: './src/css/custom.css',
        },
      }),
    ],
  ],

  themeConfig:
    /** @type {import('@docusaurus/preset-classic').ThemeConfig} */
    ({
      image: 'img/social-card.png',
      navbar: {
        title: 'LEVERAGED',
        logo: {
          alt: 'LEVERAGED Logo',
          src: 'img/logo.svg',
        },
        items: [
          {
            type: 'docSidebar',
            sidebarId: 'docs',
            position: 'left',
            label: 'Docs',
          },
          {
            href: 'https://app.leveraged.finance',
            label: 'Launch App',
            position: 'right',
          },
          {
            href: 'https://github.com/leveraged-finance/leveraged',
            label: 'GitHub',
            position: 'right',
          },
        ],
      },
      footer: {
        style: 'dark',
        links: [
          {
            title: 'Docs',
            items: [
              { label: 'Introduction', to: '/' },
              { label: 'How It Works', to: '/overview/how-it-works' },
              { label: 'Tokenomics', to: '/token/tokenomics' },
            ],
          },
          {
            title: 'Community',
            items: [
              { label: 'Discord', href: 'https://discord.gg/leveraged' },
              { label: 'Twitter', href: 'https://twitter.com/leveraged_fi' },
              { label: 'Telegram', href: 'https://t.me/leveraged_fi' },
            ],
          },
          {
            title: 'More',
            items: [
              { label: 'GitHub', href: 'https://github.com/leveraged-finance/leveraged' },
              { label: 'Medium', href: 'https://medium.com/@leveraged' },
            ],
          },
        ],
        copyright: `Copyright © ${new Date().getFullYear()} LEVERAGED. All rights reserved.`,
      },
      prism: {
        theme: themes.github,
        darkTheme: themes.dracula,
        additionalLanguages: ['solidity', 'bash', 'json'],
      },
      colorMode: {
        defaultMode: 'dark',
        disableSwitch: false,
        respectPrefersColorScheme: true,
      },
    }),
};

module.exports = config;

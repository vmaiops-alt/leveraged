/** @type {import('@docusaurus/plugin-content-docs').SidebarsConfig} */
const sidebars = {
  docs: [
    'intro',
    {
      type: 'category',
      label: 'Overview',
      collapsed: false,
      items: [
        'overview/features',
        'overview/how-it-works',
        'overview/fees',
        'overview/roadmap',
      ],
    },
    {
      type: 'category',
      label: 'Protocol',
      items: [
        'protocol/architecture',
        'protocol/vault',
        'protocol/lending',
        'protocol/liquidations',
        'protocol/oracles',
        'protocol/strategies',
      ],
    },
    {
      type: 'category',
      label: '$LVG Token',
      items: [
        'token/tokenomics',
        'token/staking',
        'token/discounts',
        'token/governance',
      ],
    },
    {
      type: 'category',
      label: 'Developers',
      items: [
        'developers/getting-started',
        'developers/contracts',
        'developers/addresses',
        'developers/integration',
        'developers/subgraph',
        'developers/api',
      ],
    },
    {
      type: 'category',
      label: 'Security',
      items: [
        'security/audits',
        'security/bug-bounty',
        'security/risks',
      ],
    },
    {
      type: 'category',
      label: 'Resources',
      items: [
        'resources/faq',
        'resources/glossary',
        'resources/brand',
        'resources/links',
      ],
    },
  ],
};

module.exports = sidebars;

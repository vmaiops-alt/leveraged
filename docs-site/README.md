# LEVERAGED Documentation

Documentation site built with [Docusaurus](https://docusaurus.io/).

## Development

```bash
# Install dependencies
npm install

# Start dev server
npm start

# Build for production
npm run build

# Serve production build locally
npm run serve
```

## Deployment

Automatically deployed to GitHub Pages on push to `main` branch.

**URL:** https://docs.leveraged.finance (or GitHub Pages URL)

## Structure

```
docs-site/
├── docs/                 # Markdown documentation
│   ├── intro.md         # Homepage
│   ├── overview/        # Overview section
│   ├── protocol/        # Protocol docs
│   ├── token/           # Token docs
│   ├── developers/      # Developer docs
│   ├── security/        # Security docs
│   └── resources/       # Resources
├── src/
│   └── css/custom.css   # Custom styles
├── static/
│   └── img/             # Images and logos
├── docusaurus.config.js # Site config
└── sidebars.js          # Sidebar navigation
```

## Adding Content

1. Create/edit markdown files in `docs/`
2. Update `sidebars.js` if adding new pages
3. Push to `main` - auto-deploys

## Custom Domain

To use `docs.leveraged.finance`:

1. Add CNAME file to `static/` with domain
2. Configure DNS:
   - CNAME record: `docs` → `leveraged-finance.github.io`

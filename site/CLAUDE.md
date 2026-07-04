# wmux.org — Site Guide

Static landing page deployed to Netlify. No build step — pure HTML/JS/CSS.

## Deploy

```bash
npx netlify deploy --prod --dir site
```

## Structure

- `index.html` — Landing page with i18n (English, French, Arabic, Japanese)
- `i18n.js` — Language switching via URL hash (`#ar`, `#fr`, `#ja`)

## Notes

- `netlify.toml` is at the repo root, not inside `site/`
- No npm, no bundler — edit files directly

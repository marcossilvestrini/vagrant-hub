# Vagrant Hub Portal

Portal público estático construído com Astro, TypeScript e Tailwind CSS, pronto para GitHub Pages. O catálogo inicial está em `src/data/catalog.json`; boxes ficam no OneDrive e não são copiadas para o site.

## Desenvolvimento local

Requer Node.js 22.23.4 ou mais recente.

```sh
npm install
npm run dev
```

## Build e preview

```sh
npm run build
npm run preview
```

O workflow `.github/workflows/deploy-pages.yml` publica `portal/dist` ao receber alterações no portal na branch `main`. Em **Settings → Pages**, configure a origem como **GitHub Actions**.

Veja a visão geral e os documentos de arquitetura em [`../docs/`](../docs/).

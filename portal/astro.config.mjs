import tailwindcss from '@tailwindcss/vite';
import { defineConfig } from 'astro/config';

const repository = process.env.GITHUB_REPOSITORY;
const [owner, repositoryName] = repository?.split('/') ?? [];
const isUserSite = repositoryName?.toLowerCase() === `${owner?.toLowerCase()}.github.io`;
const base = process.env.GITHUB_ACTIONS && repositoryName && !isUserSite
  ? `/${repositoryName}/`
  : '/';

export default defineConfig({
  output: 'static',
  base,
  vite: { plugins: [tailwindcss()] },
});

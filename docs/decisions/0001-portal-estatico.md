# ADR 0001: começar com portal estático no GitHub Pages

- **Status:** Aceita
- **Data:** 2026-11-17

## Contexto

O objetivo inicial é publicar uma experiência pública de busca e consulta de boxes, com implementação simples e deploy automatizado. GitHub Pages serve arquivos estáticos e já está disponível junto do repositório.

## Decisão

Usar Astro com saída estática, TypeScript e Tailwind CSS. GitHub Actions compila o portal e publica `portal/dist` no GitHub Pages. A busca inicial filtra o catálogo carregado no browser.

## Consequências

- Não há custo ou manutenção de servidor de aplicação no MVP.
- URLs públicas funcionam sem login.
- API dinâmica, painel de publicação, banco de dados e métricas exigem um backend futuro.
- Builds do portal não carregam os arquivos `.box`.

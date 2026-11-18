# How-to: publicar o Vagrant Hub no GitHub Pages

O workflow `.github/workflows/deploy-pages.yml` compila `portal/` e publica `portal/dist`.

1. Envie o repositório para GitHub e mantenha a branch padrão chamada `main`.
2. Abra **Settings → Pages** no repositório.
3. Em **Build and deployment → Source**, escolha **GitHub Actions**.
4. Faça push de alterações em `portal/` para `main`, ou execute manualmente **Build and deploy Vagrant Hub** na aba Actions.
5. Consulte o job `deploy` para abrir a URL emitida pelo Pages.

Astro detecta automaticamente o nome do repositório em Actions e aplica o base path de project pages. Para um domínio próprio, configure o domínio nas opções Pages e ajuste `site`/`base` em `portal/astro.config.mjs` conforme o endereço final.

O site é estático. Esse workflow não publica conteúdo de `.box` no GitHub; os arquivos grandes continuam no OneDrive.

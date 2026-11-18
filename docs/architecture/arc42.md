# arc42 — Vagrant Hub

## 1. Introdução e objetivos

Portal independente para descobrir e consumir boxes Vagrant voltadas a laboratórios e desenvolvimento.

## 2. Restrições arquiteturais

- Primeira publicação via GitHub Pages, portanto frontend estático.
- Binários `.box` ficam fora do GitHub Pages, no OneDrive.
- Tokens OAuth permanecem no computador publicador.
- A distribuição Vagrant precisa expor URL e SHA-256.

## 3. Contexto e escopo

Visitantes consultam o portal e baixam arquivos. O mantenedor gera com Bento/Packer, customiza com Ansible e publica com rclone. GitHub Actions compila as páginas após mudanças no código.

## 4. Estratégia de solução

Astro prerenderiza páginas e integra Tailwind CSS. JSON estático alimenta catálogo e páginas de release. GitHub Pages publica a saída. OneDrive armazena os artefatos públicos e manifests por versão/provider.

## 5. Visão de building blocks

Veja [C4 nível 3](c4.md). O frontend é separado em páginas, componentes, dados, scripts e estilos.

## 6. Visão de runtime

1. O mantenedor executa build e seleciona publicação.
2. rclone envia `.box` e `metadata.json` ao OneDrive e cria links públicos.
3. O catálogo estático é atualizado e enviado para GitHub.
4. Actions gera o site e Pages distribui arquivos estáticos.
5. Visitantes abrem uma página de box e seguem o link de download.

## 7. Visão de implantação

O portal é servido pelo GitHub Pages sob HTTPS. Assets `.box` e manifests publicados ficam em armazenamento OneDrive. Build e publicação são executados na estação do mantenedor.

## 8. Conceitos transversais

- Catálogo com nome estável, versão, provider, arquitetura e checksum.
- Responsividade, foco visível, links acessíveis e preferência por movimento reduzido.
- Segredos de publicação fora do browser e do JSON público.
- Artefatos grandes fora de repositórios e deploys do site.

## 9. Decisões de arquitetura

Veja [ADRs](../decisions/). O MVP usa site estático e armazenamento separado; backend e API são decisões futuras.

## 10. Requisitos de qualidade

- Navegação rápida em mobile e desktop.
- Páginas indexáveis e conteúdo renderizado sem JavaScript cliente.
- Checksum visível antes de baixar.
- Catálogo legível por pessoas e agregável pelo futuro backend.
- Rebuild previsível por CI.

## 11. Riscos e dívida técnica

- Integração OneDrive/Vagrant tem redirecionamentos e limites do provedor.
- Atualização do índice do portal ainda é manual no MVP.
- GitHub Pages não fornece API, autenticação de autores nem métricas de downloads.
- Link anônimo pode ser revogado e precisa de rotação de metadata.

## 12. Glossário

| Termo | Definição |
|---|---|
| Box | Arquivo `.box` utilizável por Vagrant e um provider |
| Provider | Virtualizador, como VirtualBox ou VMware Workstation |
| Catálogo | JSON que relaciona box, versões, providers, URLs e checksums |
| Manifest | Metadata por versão/provider armazenada junto do artefato |
| Pages | Hospedagem estática GitHub Pages |

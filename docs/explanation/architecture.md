# Explicação: arquitetura do Vagrant Hub

O Vagrant Hub começa como catálogo público estático porque a primeira necessidade é descoberta, documentação da box e download. GitHub Pages pode servir HTML, CSS, JavaScript e JSON estáticos; Astro gera páginas no build e GitHub Actions publica o resultado.

As boxes são binários de centenas de megabytes ou vários gigabytes. Guardá-las no repositório ou no artefato Pages limita a distribuição e mistura código com storage. OneDrive mantém os binários e fornece links públicos; o portal mantém somente metadados de catálogo e links.

## Fronteiras

- **Portal:** páginas de catálogo e detalhes, busca no catálogo carregado e instruções Vagrant.
- **Catálogo de build:** JSON derivado dos manifests públicos; não contém tokens OAuth ou paths locais.
- **Armazenamento:** `.box` e manifests por versão/provider no OneDrive.
- **Publicação:** scripts PowerShell fazem upload; GitHub Actions compila e publica o portal.

## Limite da primeira versão

GitHub Pages não executa endpoints de backend. Login, painel de publicação, API dinâmica, métricas, proxy de download e indexação automática precisam de um serviço backend quando forem requisitos. A interface e o contrato de catálogo são desenhados para essa evolução.

## Formato Vagrant e distribuição

O Vagrant define metadados para agrupar versões e providers, com URL e checksum de cada artefato. O OneDrive não é um registry Vagrant e o link de compartilhamento pode envolver redirecionamentos. Por isso, a página oferece a URL e o checksum no Vagrantfile, em vez de afirmar que existe hoje uma API compatível com `vagrant box add namespace/name`.

O nome Vagrant Hub e o layout seguem o modelo de descoberta familiar, mas o serviço é independente da HashiCorp e não reutiliza marca ou infraestrutura proprietária.

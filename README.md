# Vagrant Hub

## Objetivo

Vagrant Hub reúne o catálogo público de boxes para Vagrant e as ferramentas usadas para criá-las e publicá-las. O portal foi pensado para laboratórios domésticos e ambientes de desenvolvimento reproduzíveis.

O portal público começa como um site estático no GitHub Pages. O catálogo registra box, versão, provider, arquitetura e checksum; os arquivos grandes são armazenados no OneDrive.

O repositório Bento é usado como fonte para gerar as boxes base. As customizações de laboratório são aplicadas com Ansible.

## Portal

O frontend fica em [`portal/`](./portal/), implementado com Astro, TypeScript e Tailwind CSS. Consulte a documentação organizada por necessidade do leitor em [`docs/`](./docs/).

O portal não mantém um backend próprio na primeira etapa. O catálogo do site é estático; as boxes e os manifests públicos são armazenados no OneDrive.

O projeto também mantém os fluxos de build Bento e das boxes customizadas de DNS, load balancer, gerenciamento e RKE2.

O formato público do catálogo segue o modelo documentado pelo Vagrant, com várias versões e providers por box. O HCP Vagrant está em descontinuação; Vagrant Hub é um projeto independente e não afiliado à HashiCorp.

## Pre Requisitos

- vagrant >= 2.3.0
- virtualbox >= 7.0.0

## Fase 1

Gerar boxes base usando os templates Packer do Bento oficial, com menu interativo para escolher o perfil `.pkrvars.hcl` e o provider. O menu fica em `defaults/build.ps1`; consulte [`defaults/README.md`](./defaults/README.md).

## Fase 2

Customizar boxes base preservando os dados e a configuração que já existiam nos scripts de laboratório.

## Ambiente de Build

Os fluxos de build devem funcionar em Windows e Linux sempre que os providers e suas ferramentas estiverem disponíveis.

Veja a arquitetura, decisões e plano de publicação em [`docs/architecture/`](./docs/architecture/).

## Boxes base e customizadas

As boxes customizadas usam uma box Bento local e playbooks Ansible executados dentro da VM pelo provisioner `ansible_local`:

```powershell
pwsh ./customs/build.ps1
```

O menu gera DNS (BIND), load balancer (Nginx), management (Salt) e os perfis RKE2 CP/WK. Consulte [`customs/README.md`](./customs/README.md).

## Começar

- [Tutorial: executar o portal localmente](./docs/tutorials/run-portal-locally.md)
- [How-to: publicar uma box no OneDrive](./docs/how-to/publish-box.md)
- [Referência: catálogo de boxes](./docs/reference/catalog.md)
- [Explicação: arquitetura do Vagrant Hub](./docs/explanation/architecture.md)
- [Docs do portal](./portal/README.md)




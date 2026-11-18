# Referência: catálogo de boxes

O portal armazena seu índice de apresentação em `portal/src/data/catalog.json`. Os manifests publicados ao lado de cada artefato seguem o formato de catálogo estático do Vagrant: `name`, `description` e uma lista `versions`, cada versão com `providers`.

## Identidade

- `name`: namespace e nome estável da box, como `silvestrini/debian`.
- `version`: versão da box, como `13.7`.
- `provider.name`: valor consumido pelo Vagrant, como `virtualbox` ou `vmware_desktop`.
- `provider.architecture`: arquitetura Vagrant, por exemplo `amd64` ou `arm64`.

## Provider

| Campo | Tipo | Significado |
|---|---|---|
| `name` | string | Identificador do provider |
| `url` | URL HTTPS | Compartilhamento público do arquivo `.box` |
| `checksum_type` | string | Algoritmo usado no checksum; publicações usam `sha256` |
| `checksum` | string | Digest hexadecimal do artefato |
| `architecture` | string | Arquitetura do guest |
| `default_architecture` | boolean | Provider padrão para a arquitetura |

## Layout OneDrive

```text
vagrant/
└── boxes/<sistema>/<versão>/<provider>/
    ├── <artefato>.box
    └── metadata.json
```

Cada metadata publicada descreve a versão e o provider daquele diretório. O agregador do futuro portal deve reunir documentos de mesmo `name`, combinando versões e providers em um catálogo canônico.

## Índice da interface

`catalog.json` é a projeção amigável da interface e contém `slug`, `title`, descrição, tags e downloads resolvidos para cards e páginas. Campos de caminho local e token não pertencem ao catálogo público. `box-publication.json` é estado de operação local e permanece ignorado pelo Git.

Referência normativa: [Vagrant Box Repository](https://developer.hashicorp.com/vagrant/docs/boxes/box_repository).

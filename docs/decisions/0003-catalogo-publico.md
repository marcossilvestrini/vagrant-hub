# ADR 0003: versionar o catálogo público sem dados locais

- **Status:** Aceita
- **Data:** 2026-11-17

## Contexto

O portal precisa mostrar versões, providers e integrity checks. O publicador também gera um arquivo local de operação que contém caminhos da workstation.

## Decisão

Usar metadata de catálogo compatível com o formato Vagrant para os campos públicos. Publicar um manifest por versão/provider junto do `.box`. Manter o registro operacional `box-publication.json` local e ignorado pelo Git. O site consome uma projeção sanitizada no `portal/src/data/catalog.json`.

## Consequências

- O modelo público já pode ser agregado por um serviço futuro.
- A projeção do portal e os manifests OneDrive ainda precisam de um processo de sincronização automática.
- Paths locais, credenciais e tokens não fazem parte do catálogo publicado.

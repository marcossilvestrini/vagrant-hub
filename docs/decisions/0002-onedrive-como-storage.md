# ADR 0002: manter os arquivos `.box` no OneDrive

- **Status:** Aceita
- **Data:** 2026-11-17

## Contexto

Boxes ocupam centenas de megabytes ou vários gigabytes. O site estático e o Git não devem carregar esses artefatos. O OneDrive já é a origem de distribuição pretendida.

## Decisão

Publicar `.box` em `vagrant/boxes/<sistema>/<versão>/<provider>/` no OneDrive, com link público de leitura. Guardar `metadata.json` ao lado do arquivo e mostrar SHA-256 no portal.

## Consequências

- O storage cresce sem aumentar o artefato do GitHub Pages.
- Links anônimos podem ser revogados e redirecionamentos podem exigir opções de download do Vagrant.
- O publicador precisa de OAuth local de rclone; tokens nunca chegam ao browser.
- O futuro portal deve poder substituir ou encapsular o provedor de storage.

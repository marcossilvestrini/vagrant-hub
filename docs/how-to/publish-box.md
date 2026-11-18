# How-to: publicar uma box no OneDrive

Este procedimento publica o `.box` e um manifesto público compatível com o catálogo Vagrant.

## Preparar o publicador

Configure rclone uma vez, com um remote OneDrive chamado `onedrive`, e autentique o computador que fará o upload:

```powershell
rclone config
```

O token OAuth fica no perfil local do rclone. Ele não é incluído no `.box`, no manifesto público nem no site.

## Publicar pelo menu Bento

```powershell
pwsh ./defaults/build.ps1
```

Escolha perfil e provider. Ao fim da geração, responda `s` para publicar a box atual. O script envia o artefato e cria um link anônimo somente para leitura.

## Publicar uma box já criada

```powershell
pwsh ./defaults/publish-onedrive.ps1 `
  -BoxPath ./boxes/debian/13.7/vmware/debian-13.7-x86_64.vmware.box
```

## Verificar os arquivos gerados

O diretório do provider recebe `metadata.json`, no formato de catálogo documentado pelo Vagrant. O arquivo lista o nome estável, versão, provider, arquitetura, URL do artefato e SHA-256. `box-publication.json` mantém os detalhes locais e inclui caminhos da máquina; não o publique.

O `Vagrantfile` de exemplo é atualizado com a URL e as opções de download do OneDrive. Execute-o para validar o fluxo consumidor. A URL pública é um link de download compartilhável e deve ser tratada como pública.

## Integrar o catálogo ao portal

O portal lê `portal/src/data/catalog.json` no build estático. A etapa de sincronização automática dos manifests OneDrive para esse arquivo ainda será criada. Durante o MVP, atualize o catálogo do portal com os dados da publicação e envie a alteração para a branch `main`.

Veja [o contrato de catálogo](../reference/catalog.md) e a decisão [ADRs 0002 e 0003](../decisions/).

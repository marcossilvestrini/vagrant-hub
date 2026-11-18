# Vagrant Hub — boxes base com Bento

Este menu usa os templates Packer atuais do Bento. Ele descobre os perfis de sistema operacional em `os_pkrvars` e usa `packer_templates`; não usa o formato legado de `box-config.json`.

## Preparar o Bento

Clone o repositório Bento ou o fork Bento usado pelo projeto em `defaults/bento`:

```powershell
git clone https://github.com/chef/bento.git defaults/bento
```

Para usar outro checkout, informe o caminho com `-BentoPath`.

## Requisitos

- PowerShell 7 (`pwsh`), disponível em Windows, Linux e macOS
- Packer 1.14.0 ou mais recente no `PATH`
- Packer provider instalado para cada hypervisor escolhido

## Criar uma box

Na raiz do projeto, execute o menu para escolher o perfil e um provider ou todos os providers compatíveis com o sistema operacional do host:

```powershell
pwsh ./defaults/build.ps1
```

Para usar outro checkout do Bento:

```powershell
pwsh ./defaults/build.ps1 -BentoPath ../bento
```

O menu lista VirtualBox, VMware Workstation/Fusion, Parallels Desktop Pro, UTM, QEMU e Hyper-V. Parallels e UTM exigem macOS; Hyper-V exige Windows. QEMU e Hyper-V são experimentais no Bento. A opção “Todos disponíveis neste host e perfil” considera o sistema operacional, os builders declarados no perfil Bento e as ferramentas do hypervisor instaladas; os builds selecionados rodam em paralelo. Instale e configure os hypervisors antes de iniciar. Nem todas as combinações de sistema operacional, arquitetura e provider têm suporte no Bento.

O script inicializa os plugins Packer do Bento e executa o Packer com o perfil selecionado. Depois do build, move cada arquivo `.box` para `boxes/<sistema>/<versão>/<provider>/` na raiz deste projeto e cria ali um `Vagrantfile` que aponta diretamente para o artefato local. Rode `vagrant up` dentro dessa pasta para testar. Os exemplos de Parallels, UTM e QEMU declaram o respectivo plugin Vagrant. Hyper-V pode solicitar a escolha de um switch virtual. O Vagrantfile local é regenerado a cada build para apontar para a box recém-criada; se publicar no OneDrive, ele é atualizado com a URL pública e o checksum. Ao terminar cada build, o menu pergunta se deseja publicar a box no OneDrive. Se aceitar, o script reutiliza `publish-onedrive.ps1`, atualiza o `Vagrantfile` daquela pasta para baixar a box publicada e grava `box-publication.json` ao lado dela. Se responder não, o exemplo continua apontando para o arquivo local.




## Publicar uma box no OneDrive

O script `publish-onedrive.ps1` envia a box para `vagrant/boxes/<sistema>/<versão>/<provider>/` e cria links anônimos somente para leitura. Ao lado do `.box`, publica também `metadata.json`, no formato de catálogo estático do Vagrant: nome estável (`<namespace>/<sistema>`), versão, provider, arquitetura, URL e SHA-256. O namespace padrão é `silvestrini`; altere-o com `-CatalogNamespace` ao executar `build.ps1`. O arquivo de metadados é público e não contém caminhos locais nem token OAuth.

Configure uma vez um remote chamado `onedrive` com `rclone config`, escolha o backend OneDrive e conclua o login Microsoft no navegador. O rclone guarda e renova o token localmente.

Publique uma box:

```powershell
./defaults/publish-onedrive.ps1 -BoxPath ./boxes/debian/13.7/vmware/debian-13.7-x86_64.vmware.box
```

Quando chamado pelo menu, o script publica `metadata.json` no mesmo diretório OneDrive do `.box`, atualiza o `Vagrantfile` daquela box e grava `box-publication.json` localmente com os detalhes da publicação. `metadata.json` segue o formato de catálogo documentado pelo Vagrant e pode servir de contrato de dados para o futuro portal. O JSON local e os exemplos gerados são ignorados pelo Git. Chamado manualmente sem parâmetros de destino, o script mantém os exemplos em `defaults/onedrive-example/` e o registro local em `defaults/onedrive-publication.json`.

```powershell
cd ./defaults/onedrive-example
vagrant up --provider=vmware_desktop
```

Para validar também o acesso a partir de um guest sem sessão Microsoft, rode:

```powershell
./defaults/test-onedrive-download.ps1 -PublicationFile ./defaults/onedrive-publication.json -IpAddress 192.168.0.140 -Bridge Ethernet
```

O teste cria uma VM VMware temporária com IP público, baixa a box dentro dela, confere o SHA-256 e remove a VM após sucesso. Escolha um IP livre e o nome da bridge da sua rede.

O compartilhamento precisa ser anônimo para que os consumidores baixem sem login Microsoft. O link pode ser revogado no OneDrive. O Vagrant define catálogo como um JSON com nome, versões e providers; o catálogo publicado contém um provider por versão/arquivo, e o futuro portal poderá reunir os manifests do OneDrive e expor uma API/catálogo consolidado com vários providers e versões. O portal ainda precisará tratar downloads/redirects do OneDrive ou servir os arquivos por uma URL própria; a publicação do JSON não cria, sozinha, uma API de catálogo nem garante que o link de compartilhamento do OneDrive funcione como URL direta do Vagrant.

Formato de referência: [Vagrant Box Repository](https://developer.hashicorp.com/vagrant/docs/boxes/box_repository). O HCP Vagrant está em descontinuação; este fluxo usa o formato de catálogo como referência para o portal próprio, sem depender do serviço HCP.



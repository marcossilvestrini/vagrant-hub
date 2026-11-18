# Vagrant Hub — boxes customizadas

As customs são portadas dos scripts/configurações em debug/Build/vagrant-boxes/vmware/rocky9. Os arquivos em debug/ servem como referência; a Ansible aplica cópias mantidas nas roles.

## Construir

Na raiz do projeto, execute:

    pwsh ./customs/build.ps1

Escolha uma box Bento local Rocky Linux/Oracle Linux e um perfil. O script inicia a VM temporária, aplica Ansible e empacota o resultado em boxes/custom/<sistema>/<versão>/<perfil>/<provider>/. O Vagrantfile de teste usa os hostnames e IPs da zona Skynet e as bridges listadas no Vagrantfile legado.

## Perfis portados

- dns: mantém a zona skynet.com.br, reversa 0.168.192.in-addr.arpa, DNSSEC e os endereços dos hosts que estão nos arquivos legados.
- lb: usa o nginx.conf legado com os upstreams Rancher/RKE2 em 192.168.0.140–145.
- mgt: mantém Salt Master, /srv/salt, /srv/formulas, /srv/pillar e as roots originais. O arquivo network.conf legado fica preservado como referência; ele contém o placeholder IP_MASTER e o script antigo não o instalava.
- rke2-cp e rke2-wk: usam control-plane01.skynet.com.br:9345, o token compartilhado presente nos arquivos antigos, o Canal e os SANs do primeiro control plane. Os serviços iniciam automaticamente; o endereço do nó é resolvido no primeiro boot com a interface da rede do lab.

A role common agora parte da lista de pacotes e do arquivo SSH encontrados em userdata-ol9.sh/debug. A implementação das customs é para Rocky Linux/Oracle Linux, que correspondem ao ambiente legado.

Os perfis RKE2 preservam o token de laboratório dos arquivos sincronizados em debug. Se o token mudar na configuração legada, atualize os arquivos correspondentes em customs/ansible/roles/rke2/files/ antes de gerar novamente as duas boxes.



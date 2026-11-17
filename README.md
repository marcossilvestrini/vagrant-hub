# Criando Vagrant Boxes para Homelabs

## Objetivo

O objetivo deste projeto e criar vagrant boxes para serem utilizadas em ambientes de desenvolvimento.

Com o fim do HCL Vagrant, não teremos mais a possibilidade de baixar os boxes do registry oficial, então a ideia é criar boxes customizadas para uso interno.

Vamos usar um fork do projeto Bento Boxes, que é um projeto open source que cria boxes para vagrant.

Após criar as boxes defaults, vamos customizar elas para atender as necessidades do nosso ambiente de desenvolvimento.

Na pasta debug/, publiquei uma pasta que usei por um tempo para criar as boxes dos meus homelabs.

Leia ela e vamos reaproveitar para criar as boxes customizadas com base nas que criarewmos com o Bento Boxes.

Ao final, espera-se que tenhamos boxes defaults de cada SO, e boxes customizadas para atender as necessidades do nosso ambiente de desenvolvimento. Como por exemplo boxes de dns, lb,mgt,rke2-cp,rke2-wk, etc.

Usaremos boxes local em cada novo projeto, e não vamos mais depender do registry oficial do vagrant.

Pelo que vi, o repositorio oficial do Bento ja vai nos dar quase tudo para criarmos os boxes defaults, então vamos aproveitar o que ja existe e customizar para atender as nossas necessidades.

Usar ferramentas como packer e ansible para criar os boxes customizados.

A execução da criação dos boxes default deve ter um menu interativo para escolher qual box criar.

Para as boxes customizadas, use build como base e crie um menu interativo para escolher qual box customizada criar.

Devemos estar preparados tambem para adiciionar novas defaults e novas customizadas, então o projeto deve ser de facil manutenção e evolução.

## Pre Requisitos

- vagrant >= 2.3.0
- virtualbox >= 7.0.0

## Fase 1

Criar boxes default usando os templates Packer do Bento atual (ou fork baseado nele), com menu interativo para escolher o perfil `.pkrvars.hcl` e o provider. O menu fica em `defaults/build.ps1`; consulte `defaults/README.md`.

## Fase 2

Customizar boxes default para atender as necessidades do nosso ambiente de desenvolvimento.(reutilize se possível e atualize o conceito da pasta debug/)

## Ambiente de Build

Nossa automação devera funcionar tanto em Windows quanto em Linux, então vamos criar um ambiente de build que funcione em ambos os sistemas operacionais.

No meu caso, estou usando o Windows 11, então vou criar um ambiente de build no Windows, mas a ideia é que funcione em ambos os sistemas operacionais.

Para isso, como vamos usar muitas ferramentas que rodam em windows, vamos ter que criar uma box linux que será a executura do nosso ambiente de build, e dentro dela vamos instalar todas as ferramentas necessárias para criar as boxes.


## Referências

- [Bento - templates Packer oficiais](https://github.com/chef/bento)


## Fase 2 - Boxes customizadas

As boxes customizadas usam uma box Bento local e playbooks Ansible executados dentro da VM pelo provisioner `ansible_local`:

```powershell
pwsh ./customs/build.ps1
```

O menu gera dns (BIND), lb (Nginx), mgt (Salt) e os perfis rke2-cp e rke2-wk. Consulte [customs/README.md](./customs/README.md) para adicionar perfis e testar as boxes localmente.




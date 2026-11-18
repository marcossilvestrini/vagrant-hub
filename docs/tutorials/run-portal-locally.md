# Tutorial: executar o portal localmente

Este tutorial inicia o Vagrant Hub no computador de desenvolvimento e mostra uma box no catálogo.

## 1. Instale as ferramentas

Instale Node.js 22.23.4 ou mais recente e npm. A stack do portal é Astro estático com TypeScript e Tailwind CSS.

## 2. Instale as dependências

Na raiz do repositório:

```powershell
cd portal
npm install
```

## 3. Inicie o servidor de desenvolvimento

```powershell
npm run dev
```

Abra o endereço local mostrado pelo Astro. A home apresenta as boxes em destaque; **Explorar boxes** abre o catálogo e cada cartão leva à página detalhada.

## 4. Explore uma página de box

Abra Debian 13.7. Confira provider, arquitetura, tamanho e SHA-256. O botão de download abre o compartilhamento do OneDrive. O bloco de código mostra a configuração Vagrant correspondente.

## 5. Gere a versão estática

```powershell
npm run build
npm run preview
```

Astro escreve a saída em `portal/dist`. O workflow do GitHub Pages publica essa pasta após uma alteração na branch `main`.

## Próximo passo

Veja [publicar uma box](../how-to/publish-box.md) e [o formato do catálogo](../reference/catalog.md).

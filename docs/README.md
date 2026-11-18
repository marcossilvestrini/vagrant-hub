# Documentação do Vagrant Hub

A documentação combina [Diátaxis](https://diataxis.fr/) para guias voltados ao leitor, [C4](https://c4model.com/) e [arc42](https://arc42.org/) para arquitetura e ADRs para registrar decisões técnicas.

## Escolha por necessidade

| Preciso... | Leia |
|---|---|
| rodar o portal pela primeira vez | [Tutorial: portal local](tutorials/run-portal-locally.md) |
| publicar uma box | [How-to: publicar no OneDrive](how-to/publish-box.md) |
| entender o JSON do catálogo | [Referência: catálogo](reference/catalog.md) |
| entender por que o portal é estático | [Explicação: arquitetura](explanation/architecture.md) |
| ver limites, contexto e implantação | [C4](architecture/c4.md) e [arc42](architecture/arc42.md) |
| revisar decisões já tomadas | [ADRs](decisions/) |

## Organização

- `tutorials/`: aprendizado orientado por uma tarefa completa.
- `how-to/`: procedimentos para tarefas específicas.
- `reference/`: contratos, campos e comandos descritos sem narrativa tutorial.
- `explanation/`: contexto, motivos e consequências.
- `architecture/`: diagramas C4 e visão arc42.
- `decisions/`: registros de decisões arquiteturais.

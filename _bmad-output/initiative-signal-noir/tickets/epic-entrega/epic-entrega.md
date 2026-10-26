---
type: epic
title: "Instalação cruzada, documentação, vídeo e inscrição (B13–B14)"
parent: initiative-signal-noir
covers: [R47, R48, R49, R50]
sources: [_bmad-output/initiative-signal-noir/initiative-signal-noir.md]
companions: [_bmad-output/initiative-signal-noir/architecture-signal-noir/architecture-signal-noir.md]
after: []
refined: false
risk: medium
specs: [specs/012-packaging-and-cross-install]
owner: "Henry (012 e README); Henrique (instalação cruzada em máquina limpa)"
window: "G4 (012; validação final depois de todas as specs)"
---

# Instalação cruzada, documentação, vídeo e inscrição (B13–B14)

## Description

Validação independente da instalação e do smoke (B13) e o pacote final com a inscrição no concurso (B14).

## Outcome

Em 07/11, a versão submetível está instalada por outro integrante e inscrita.

## Done when

- B13: instalação só pelo README; build e imagem verificáveis; smoke real com chave própria.
- B13: reinício, recriação e reset batem com o documentado; plataforma não testada não é anunciada; logs e exports sem segredos; correção de instalação dispara nova validação.
- B14: README em inglês com instalação, configuração, smoke, benchmark e limitações; código e licença disponíveis; vídeo da versão entregue com dados sintéticos.
- B14: resultados divulgados = relatório; perfis e links conferidos; página do app e inscrição verificadas; pendências dos organizadores com responsável.

## Boundaries

- Funcionalidade nova depois de 05/11.
- Shared R47: aqui, o B13 valida reinício, recriação e reset documentados. epic-fundacao-e-simulador: o B04 entrega imagem local e bootstrap idempotente.
- Shared R48: aqui, o B13 confere logs e exports sem segredos. epic-fundacao-e-simulador: o B04 sobe sem chave válida e mantém segredos fora de código e eventos.

## References

- parent — _bmad-output/initiative-signal-noir/initiative-signal-noir.md, section Requirements
- architecture — _bmad-output/initiative-signal-noir/architecture-signal-noir/architecture-signal-noir.md

## Notes

- Status: planejado; aceite ainda não demonstrado. Refinar com Sofia (`bmad-agent-po`) antes de planejar as histórias.

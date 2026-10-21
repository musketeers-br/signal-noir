---
type: epic
title: "Ambiente, primeira fatia persistida e simulador HTTP (B04–B05)"
parent: initiative-signal-noir
covers: [R5, R7, R8, R11, R25, R40, R47, R48]
sources: [_bmad-output/initiative-signal-noir/initiative-signal-noir.md]
companions: [_bmad-output/initiative-signal-noir/architecture-signal-noir/architecture-signal-noir.md]
after: []
refined: false
risk: medium
owner: "José (B04), Henry (B05)"
window: "26–28/10"
---

# Ambiente, primeira fatia persistida e simulador HTTP (B04–B05)

## Description

Sobe o ambiente da submissão com bootstrap idempotente e a primeira fatia real: uma falha abre um Caso persistido e o AI Hub produz uma Proposta ligada a ele (B04). Em paralelo, o Simulador HTTP materializa o Parceiro, a Origem e as fontes de Evidência com falhas controladas (B05).

## Outcome

Menor prova real em 27/10: Agente em BO, Proposta persistida e recuperável.

## Done when

- B04: o ambiente inicia pelos passos documentados; uma falha abre Caso persistido; o AI Hub produz Proposta real ligada ao Caso.
- B04: Proposta e Evidências sobrevivem a reinício; sem chave válida o app inicia e informa indisponibilidade; segredos fora de código, eventos e exports.
- B05: a variante P1 de P5 roda sem espera real de 90 s (escala de tempo do Simulador).
- B05: instâncias isoladas; a mesma semente reproduz o cenário; o Parceiro aceita e pode perder a resposta.
- B05: mesma chave e payload devolvem o Recibo original; chave reutilizada com payload incompatível é rejeitada; mudança pós-Aprovação sincronizável; nenhuma Ferramenta expõe o Gabarito.

## Boundaries

- Interface rica e Cenários múltiplos ficam suspensos se a prova de 27/10 falhar.
- Shared R8: aqui, o B04 entrega o primeiro Caso persistido e a Production como transporte. epic-caso-e-decisao: o B06 entrega espera humana persistida e trabalho novo pelo outbox.
- Shared R11: aqui, o B04 persiste Proposta e Evidências com sobrevivência a reinício. epic-caso-e-decisao: o B06 garante Linha do Tempo append-only e bloqueio sem registro de autorização.
- Shared R25: aqui, o B05 implementa a deduplicação atômica no Simulador. epic-execucao-segura: o B09 depende dela para a Reconciliação.
- Shared R47: aqui, o B04 entrega imagem local e bootstrap idempotente. epic-entrega: o B13 valida reinício, recriação e reset documentados.
- Shared R48: aqui, o B04 sobe sem chave válida e mantém segredos fora de código e eventos. epic-entrega: o B13 confere logs e exports sem segredos.

## References

- parent — _bmad-output/initiative-signal-noir/initiative-signal-noir.md, section Requirements
- architecture — _bmad-output/initiative-signal-noir/architecture-signal-noir/architecture-signal-noir.md

## Notes

- Status: planejado; aceite ainda não demonstrado. Refinar com Sofia (`bmad-agent-po`) antes de planejar as histórias.

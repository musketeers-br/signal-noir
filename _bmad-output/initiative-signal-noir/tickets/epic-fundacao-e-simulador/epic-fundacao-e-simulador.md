---
id: 3
type: epic
title: "Ambiente, primeira fatia persistida e simulador HTTP (B04–B05)"
parent: ../../initiative-signal-noir.md
covers: [R7, R8, R11, R25, R40, R47, R48]
sources: [../../initiative-signal-noir.md]
companions: [../../architecture-signal-noir/architecture-signal-noir.md]
after: [2]
refined: false
hitl: false
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
- B05: instâncias isoladas; a mesma semente reproduz o cenário; o Parceiro aceita e pode perder a resposta.
- B05: mesma chave e payload devolvem o Recibo original; chave reutilizada com payload incompatível é rejeitada; mudança pós-Aprovação sincronizável; nenhuma Ferramenta expõe o Gabarito.

## Boundaries

- Interface rica e Cenários múltiplos ficam suspensos se a prova de 27/10 falhar.

## Notes

- Status: planejado; aceite ainda não demonstrado. Refinar com Sofia (`bmad-agent-po`) antes de planejar as histórias.

---
id: 7
type: epic
title: "P9: entrega prévia sob outro identificador (condicionado)"
parent: ../../initiative-signal-noir.md
covers: [R4]
sources: [../../initiative-signal-noir.md]
companions: [../../architecture-signal-noir/architecture-signal-noir.md]
after: [5, 6]
refined: false
hitl: false
risk: medium
owner: "Henry (cenário), José (Validador)"
window: "após B09 e B10"
---

# P9: entrega prévia sob outro identificador (condicionado)

## Description

O Agente descobre que o Pedido 'falho' já foi entregue sob outro Identificador de Transação. O Validador confirma a Chave de Equivalência antes de encerrar como ResolvedByPriorReceipt.

## Outcome

Uma história memorável para a demo, sem comprometer B12–B14.

## Done when

- Com Chave de Equivalência confirmada, nenhuma Execução ocorre e o Caso fica vinculado ao Recibo anterior.
- Sem identidade inequívoca, o Caso vai para revisão com o candidato no Dossiê.

## Boundaries

- Entra só se B09 e B10 estiverem aceitos; sai primeiro em qualquer corte.

## Notes

- Status: planejado; aceite ainda não demonstrado. Refinar com Sofia (`bmad-agent-po`) antes de planejar as histórias.

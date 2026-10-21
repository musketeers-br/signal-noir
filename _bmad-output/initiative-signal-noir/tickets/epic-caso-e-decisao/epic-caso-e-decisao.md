---
id: 4
type: epic
title: "Estado, Aprovação, outbox, propositor e Validador (B06, B08)"
parent: ../../initiative-signal-noir.md
covers: [R1, R8, R11, R12, R13, R14, R15, R16, R18, R19, R20, R21, R22, R23, R28]
sources: [../../initiative-signal-noir.md]
companions: [../../architecture-signal-noir/architecture-signal-noir.md]
after: [3]
refined: false
hitl: false
risk: high
owner: "José"
window: "27–31/10 (primeira fatia de B08 até 29/10)"
---

# Estado, Aprovação, outbox, propositor e Validador (B06, B08)

## Description

Implementa os comandos transacionais do Caso, a Aprovação vinculada à versão exata e o outbox com recuperação (B06). Implementa a Investigação P5/P8b, a Proposta estruturada e o Validador determinístico comum a todos os propositores (B08).

## Outcome

O cenário principal P5/P8b produz uma Proposta validada e aprovável, com garantias de concorrência.

## Done when

- B06: duas Aprovações concorrentes geram uma autorização efetiva; Proposta vencida ou substituída é recusada.
- B06: estado, evento e outbox confirmam juntos; falha após commit não perde trabalho; comando repetido é seguro; leitura incremental não perde eventos confirmados tarde; transições permitidas e proibidas testadas.
- B08: Ação, parâmetros e mapeamento inválidos bloqueados; falta de Evidência gera revisão com motivo; o Agente não tem Ferramentas de escrita.
- B08: contexto e orçamento impostos pelo servidor; resposta tardia não altera Investigação encerrada; testes de instrução embutida registram decisão e bloqueio.

## Boundaries

- Execução e Reconciliação (épico 6).

## Notes

- Status: planejado; aceite ainda não demonstrado. Refinar com Sofia (`bmad-agent-po`) antes de planejar as histórias.

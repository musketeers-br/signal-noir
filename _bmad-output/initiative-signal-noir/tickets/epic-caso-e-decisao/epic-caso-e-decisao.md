---
type: epic
title: "Estado, Aprovação, outbox, propositor e Validador (B06, B08)"
parent: initiative-signal-noir
covers: [R1, R8, R11, R12, R13, R14, R15, R16, R18, R19, R20, R21, R22, R23, R28]
sources: [_bmad-output/initiative-signal-noir/initiative-signal-noir.md]
companions: [_bmad-output/initiative-signal-noir/architecture-signal-noir/architecture-signal-noir.md]
after: []
refined: false
risk: high
specs: [specs/003-order-case-lifecycle, specs/004-validation-and-reference-data, specs/006-investigation-and-proposal, specs/007-approval-and-outbox]
owner: "Henry (003, 006); Henrique (004, 007)"
window: "G1–G2 (003 e 004 em G1; 006 e 007 em G2)"
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
- Shared R12: aqui, o B08 implementa a Investigação no modo decidido. epic-contratos-e-spike: o spike B02 decide entre Ferramentas no BO e Evidência Pré-coletada.
- Shared R16: aqui, o B08 grava esses dados em cada Investigação. epic-contratos-e-spike: o spike B02 confirma o que o build 154 expõe (modelo, duração, tokens).
- Shared R8: aqui, o B06 entrega espera humana persistida e trabalho novo pelo outbox. epic-fundacao-e-simulador: o B04 entrega o primeiro Caso persistido e a Production como transporte.
- Shared R11: aqui, o B06 garante Linha do Tempo append-only e bloqueio sem registro de autorização. epic-fundacao-e-simulador: o B04 persiste Proposta e Evidências com sobrevivência a reinício.
- Shared R28: aqui, o B06 entrega estado, evento e outbox na mesma transação. epic-execucao-segura: o B09 entrega lease com geração e worker atrasado sem sobrescrita.

## References

- parent — _bmad-output/initiative-signal-noir/initiative-signal-noir.md, section Requirements
- architecture — _bmad-output/initiative-signal-noir/architecture-signal-noir/architecture-signal-noir.md

## Notes

- Status: planejado; aceite ainda não demonstrado. Refinar com Sofia (`bmad-agent-po`) antes de planejar as histórias.

---
id: 6
type: epic
title: "Execução, Revalidação e Reconciliação (B09)"
parent: ../../initiative-signal-noir.md
covers: [R3, R24, R25, R26, R27, R28, R29]
sources: [../../initiative-signal-noir.md]
companions: [../../architecture-signal-noir/architecture-signal-noir.md]
after: [3, 4]
refined: false
hitl: false
risk: high
owner: "José (revisão conjunta dos três)"
window: "29/10–02/11"
---

# Execução, Revalidação e Reconciliação (B09)

## Description

Caminho único de entrega inicial e de recuperação: autorização persistida, Revalidação antes do envio, idempotência pelo businessEffectKey, Reconciliação de resultado incerto e lease com geração.

## Outcome

Em 02/11, Aprovação, Revalidação e Reconciliação estão comprovadas, incluindo P3.

## Done when

- Autorização persistida antes do efeito; Revalidação impeditiva bloqueia o envio.
- Timeout após aceitação recupera o Recibo sem novo efeito; reinício preserva a Reconciliação.
- Worker sem posse válida não sobrescreve estado posterior; resultado desconhecido bloqueia novo envio; nova Proposta não contorna execução incerta.
- Saída de espera exige nova Proposta e Aprovação quando aplicável.

## Boundaries

- Se o marco de 02/11 falhar, as Ações executáveis ficam restritas às testadas.

## Notes

- Status: planejado; aceite ainda não demonstrado. Refinar com Sofia (`bmad-agent-po`) antes de planejar as histórias.

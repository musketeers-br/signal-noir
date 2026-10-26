---
type: epic
title: "Execução, Revalidação e Reconciliação (B09)"
parent: initiative-signal-noir
covers: [R3, R24, R25, R26, R27, R28, R29]
sources: [_bmad-output/initiative-signal-noir/initiative-signal-noir.md]
companions: [_bmad-output/initiative-signal-noir/architecture-signal-noir/architecture-signal-noir.md]
after: []
refined: false
risk: high
specs: [specs/008-execution-and-recovery]
owner: "Henrique (008). Sem revisão conjunta com o José: ele saiu para outro projeto"
window: "G3 (008; sem spec ainda, só prompt em docs/specify-prompts/)"
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
- Shared R24: aqui, o B09 implementa a derivação e o uso na Execução. epic-contratos-e-spike: o B01 fixa as três identidades no contrato (incluindo a API-Q11).
- Shared R25: aqui, o B09 depende dela para a Reconciliação. epic-fundacao-e-simulador: o B05 implementa a deduplicação atômica no Simulador.
- Shared R28: aqui, o B09 entrega lease com geração e worker atrasado sem sobrescrita. epic-caso-e-decisao: o B06 entrega estado, evento e outbox na mesma transação.

## References

- parent — _bmad-output/initiative-signal-noir/initiative-signal-noir.md, section Requirements
- architecture — _bmad-output/initiative-signal-noir/architecture-signal-noir/architecture-signal-noir.md

## Notes

- Status: planejado; aceite ainda não demonstrado. Refinar com Sofia (`bmad-agent-po`) antes de planejar as histórias.

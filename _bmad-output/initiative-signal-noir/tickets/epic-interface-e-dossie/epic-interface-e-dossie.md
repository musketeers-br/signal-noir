---
type: epic
title: "Interface operacional integrada e Dossiê de Revisão (B07, B10)"
parent: initiative-signal-noir
covers: [R2, R30, R31, R32, R33, R34, R35]
sources: [_bmad-output/initiative-signal-noir/initiative-signal-noir.md]
companions: [_bmad-output/initiative-signal-noir/architecture-signal-noir/architecture-signal-noir.md, _bmad-output/initiative-signal-noir/ux-signal-noir/DESIGN.md, _bmad-output/initiative-signal-noir/ux-signal-noir/EXPERIENCE.md]
after: []
refined: false
risk: medium
specs: [specs/005-operator-console, specs/009-review-dossier-and-resolution]
owner: "Henry (005 console e 009 Dossiê, com a rubrica); Henrique revisa a interface (sem spec de revisão no board)"
window: "G2–G3 (005 em G2; 009 em G3)"
---

# Interface operacional integrada e Dossiê de Revisão (B07, B10)

## Description

Constrói a SPA (lista, detalhe, Evidências, Aprovação e resultado) integrada ao backend (B07). Constrói o Dossiê operacional e a resolução humana pelo mesmo caminho de validação (B10). É escrita do zero a partir de 26/10, com o protótipo só como referência.

## Outcome

Em 29/10, um Caso P5/P8b real aparece na interface da falha ao resultado.

## Done when

- B07: Caso real aparece e atualiza sem recarga; Evidências navegáveis; a Aprovação envia a versão exata.
- B07: conflito de versão não gera sucesso falso; espera, revisão e incerteza com mensagens distintas; dados sintéticos identificados.
- B10: motivo, Evidências, divergências e próximo passo presentes; funciona mesmo com falha precoce do LLM.
- B10: nenhuma consulta ou Evidência inventada; ausência de informação distinta de conclusão negativa; escolha humana pelo mesmo Validador; cancelamento e autoria declarada registrados.

## Boundaries

- Canvas, editor de Productions e Replay na interface.
- Shared R32: aqui, o B07 e o B10 constroem a SPA sobre eles. epic-contratos-e-spike: o B03 fixa contrato HTTP, fixtures e especificação de telas.
- Shared R33: aqui, o B07 implementa e testa na SPA integrada. epic-contratos-e-spike: o B03 define o comportamento de Aprovação e conflito de versão.
- Shared R34: aqui, o B07 e o B10 implementam. epic-contratos-e-spike: o B03 define as mensagens e estados de apresentação.

## References

- parent — _bmad-output/initiative-signal-noir/initiative-signal-noir.md, section Requirements
- architecture — _bmad-output/initiative-signal-noir/architecture-signal-noir/architecture-signal-noir.md

## Notes

- Status: planejado; aceite ainda não demonstrado. Refinar com Sofia (`bmad-agent-po`) antes de planejar as histórias.

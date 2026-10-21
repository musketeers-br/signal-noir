---
id: 5
type: epic
title: "Interface operacional integrada e Dossiê de Revisão (B07, B10)"
parent: ../../initiative-signal-noir.md
covers: [R2, R30, R31, R32, R33, R34, R35]
sources: [../../initiative-signal-noir.md]
companions: [../../architecture-signal-noir/architecture-signal-noir.md]
after: [2, 3]
refined: false
hitl: false
risk: medium
owner: "Henrique (José no comando de resolução; Henry no conteúdo e na rubrica)"
window: "27/10–02/11"
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

## Notes

- Status: planejado; aceite ainda não demonstrado. Refinar com Sofia (`bmad-agent-po`) antes de planejar as histórias.

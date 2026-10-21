---
type: epic
title: "Baseline, executor e Execução de Referência (B11–B12)"
parent: initiative-signal-noir
covers: [R6, R42, R43, R44, R45, R46]
sources: [_bmad-output/initiative-signal-noir/initiative-signal-noir.md]
companions: [_bmad-output/initiative-signal-noir/architecture-signal-noir/architecture-signal-noir.md]
after: []
refined: false
risk: medium
owner: "Henry (José no baseline; Henrique na revisão do avaliador)"
window: "02–05/11"
---

# Baseline, executor e Execução de Referência (B11–B12)

## Description

Comparação reproduzível entre o Modo Regras e o Modo Regras + Agente, com avaliador de categorias inequívocas (B11), e a Execução de Referência congelada e publicada (B12).

## Outcome

Em 05/11 há um relatório versionado com dados brutos, honesto sobre ganho, empate ou perda.

## Done when

- B11: mesmas Ferramentas e proteções para regras e Agente; pontuação por Ação e parâmetros; proposta errada bloqueada separada de efeito errado; revisão necessária e desnecessária definidas.
- B11: Aprovação automática restrita ao benchmark; o export permite recalcular; o teste reservado não foi usado para ajuste.
- B12: prompt, baseline, modelo, políticas, fixtures e avaliador congelados; P5 e P8b com 5 variantes e 3 repetições; controles limpos e Dossiê incluídos.
- B12: Garantias da Plataforma separadas; contagens, denominadores, dispersão, latência e custo publicados; falhas e empates preservados; Replay não conta como execução real.

## Boundaries

- Ajuste com o conjunto de teste invalida aquela avaliação final (R44).

## References

- parent — _bmad-output/initiative-signal-noir/initiative-signal-noir.md, section Requirements
- architecture — _bmad-output/initiative-signal-noir/architecture-signal-noir/architecture-signal-noir.md

## Notes

- Status: planejado; aceite ainda não demonstrado. Refinar com Sofia (`bmad-agent-po`) antes de planejar as histórias.

---
id: 2
type: epic
title: "Contratos de domínio, spike do AI Hub 154 e contrato da UX (B01–B03)"
parent: ../../initiative-signal-noir.md
covers: [R9, R10, R12, R16, R17, R24, R32, R33, R34, R37, R41]
sources: [../../initiative-signal-noir.md]
companions: [../../architecture-signal-noir/architecture-signal-noir.md]
after: [1]
refined: false
hitl: false
risk: medium
owner: "Henry (B01), José (B02), Henrique (B03)"
window: "até 25/10"
---

# Contratos de domínio, spike do AI Hub 154 e contrato da UX (B01–B03)

## Description

Preparação permitida antes de 26/10. Congela os contratos de Pedido, Caso, Proposta, Aprovação, Execução, Recibo e Simulador e a tabela de estados (B01). Prova em spike descartável, fora do repositório, o que o AI Hub 154 faz dentro de um BO (B02). Fixa o contrato HTTP, as fixtures e a especificação das telas, com base nos aprendizados do protótipo (B03).

## Outcome

As três frentes começam em 26/10 contra contratos estáveis e com o risco do build 154 conhecido.

## Done when

- B01: campos obrigatórios, erros, versões e identidades (commandId, executionId, businessEffectKey) definidos.
- B01: cada Ação tem Evidência mínima e condições verificáveis; os estados cobrem envio inicial, espera, rejeição, expiração, incerteza e encerramento.
- B01: negativos de mapeamento, identidade e Recibo incluídos; regra de novo episódio após Caso terminal definida; separação entre ajuste e teste estabelecida.
- B02: o BO chama o Agente e recebe Proposta estruturada; ao menos uma Ferramenta de leitura funciona no contexto correto; credenciais funcionam no job.
- B02: modelo, duração e tokens capturados quando disponíveis; chave inválida, formato inválido e timeout observados; fallback de Evidência Pré-coletada definido.
- B03: as fixtures cobrem investigação, Aprovação, versão vencida, espera, incerteza, resolução e revisão; a Aprovação mostra o efeito exato.
- B03: fato e diagnóstico distinguíveis; falha do Provedor e ausência de dados têm apresentação; vocabulário igual ao do domínio; findings do protótipo incorporados ou recusados com motivo.
- AD-21 e openapi-sim.yaml atualizados para businessEffectKey (pendência do reconcile).

## Boundaries

- Implementação do código da submissão (começa em 26/10).

## Notes

- Status: planejado; aceite ainda não demonstrado. Refinar com Sofia (`bmad-agent-po`) antes de planejar as histórias.

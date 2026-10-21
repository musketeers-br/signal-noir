---
type: epic
title: "Contratos de domínio, spike do AI Hub 154 e contrato da UX (B01–B03)"
parent: initiative-signal-noir
covers: [R9, R10, R12, R16, R17, R24, R32, R33, R34, R37, R41]
sources: [_bmad-output/initiative-signal-noir/initiative-signal-noir.md]
companions: [_bmad-output/initiative-signal-noir/architecture-signal-noir/architecture-signal-noir.md]
after: []
refined: false
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
- Shared R37: aqui, o B03 aceita ou recusa essas propostas no contrato. epic-prototipo-solucao: as fixtures do protótipo seguem o contrato e geram propostas de mudança.
- Shared R12: aqui, o spike B02 decide entre Ferramentas no BO e Evidência Pré-coletada. epic-caso-e-decisao: o B08 implementa a Investigação no modo decidido.
- Shared R16: aqui, o spike B02 confirma o que o build 154 expõe (modelo, duração, tokens). epic-caso-e-decisao: o B08 grava esses dados em cada Investigação.
- Shared R24: aqui, o B01 fixa as três identidades no contrato (incluindo a API-Q11). epic-execucao-segura: o B09 implementa a derivação e o uso na Execução.
- Shared R32: aqui, o B03 fixa contrato HTTP, fixtures e especificação de telas. epic-interface-e-dossie: o B07 e o B10 constroem a SPA sobre eles.
- Shared R33: aqui, o B03 define o comportamento de Aprovação e conflito de versão. epic-interface-e-dossie: o B07 implementa e testa na SPA integrada.
- Shared R34: aqui, o B03 define as mensagens e estados de apresentação. epic-interface-e-dossie: o B07 e o B10 implementam.

## References

- parent — _bmad-output/initiative-signal-noir/initiative-signal-noir.md, section Requirements
- architecture — _bmad-output/initiative-signal-noir/architecture-signal-noir/architecture-signal-noir.md

## Notes

- Decision (21/10): o épico não espera o protótipo. Só a história do B03 depende dele; ao planejar as histórias, a entrada do B03 leva `after = ["epic-prototipo-solucao"]`. B01 e B02 começam já.
- Status: planejado; aceite ainda não demonstrado. Refinar com Sofia (`bmad-agent-po`) antes de planejar as histórias.

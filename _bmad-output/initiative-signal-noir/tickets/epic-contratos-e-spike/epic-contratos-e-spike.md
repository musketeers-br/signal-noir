---
type: epic
title: "Contratos de domínio, spike do AI Hub 154 e contrato da UX (B01–B03)"
parent: initiative-signal-noir
covers: [R9, R10, R12, R16, R17, R24, R32, R33, R34, R37, R41]
sources: [_bmad-output/initiative-signal-noir/initiative-signal-noir.md]
companions: [_bmad-output/initiative-signal-noir/architecture-signal-noir/architecture-signal-noir.md]
after: []
refined: true
risk: medium
owner: "Henry (B01), José (B02), Henrique (B03)"
window: "até 25/10"
---

# Contratos de domínio, spike do AI Hub 154 e contrato da UX (B01–B03)

## Description

Preparação permitida antes de 26/10. Congela os contratos de Pedido, Caso, Proposta, Aprovação, Execução, Recibo e Simulador e a tabela de estados (B01). Prova em spike descartável, fora do repositório, o que o AI Hub 154 faz dentro de um BO (B02). Fixa o contrato HTTP, as fixtures e a especificação das telas, com base nos aprendizados do protótipo (B03).

## Outcome

As três frentes começam em 26/10 contra contratos estáveis e com o risco do build 154 conhecido.

## Requirements

- R1 (parent R9) Há uma única máquina de estados. B01 a congela com origem, destino, ator, pré-condições, evento e trabalho subsequente de cada transição.
- R2 (parent R10) Estados terminais não reabrem implicitamente. Um novo episódio depois de um estado terminal cria um Caso relacionado. Rejeição e expiração têm destino e limite. `Held` só sai por nova Investigação.
- R3 (parent R12) O Agente só tem Ferramentas de leitura. O servidor impõe o contexto e o orçamento. A Evidência Pré-coletada substitui as Ferramentas como plano B, mas a chamada real ao AI Hub continua.
- R4 (parent R16) Cada Investigação registra modelo, Provedor, versões, duração, Chamadas de Ferramenta e tokens, quando disponíveis.
- R5 (parent R17) Um Provedor e um modelo de referência são demonstrados. A troca por `.env` continua possível, mas o suporte aos quatro Provedores não é garantido nem anunciado.
- R6 (parent R24) Há três identidades separadas: - `commandId` para o trabalho interno; - `executionId` para a execução autorizada, seu lease e sua Reconciliação; - `businessEffectKey` para o efeito no Parceiro. A identidade do efeito não depende só de `proposalId`.
- R7 (parent R32) A interface é uma SPA estática, com polling e contratos HTTP versionados. Ela oferece lista, detalhe em camadas, Aprovação, Dossiê e resultado, e mostra o problema, as Evidências, a alteração prevista e o resultado.
- R8 (parent R33) A Aprovação mostra o efeito exato e envia a versão exata. Um conflito de versão exige atualizar a Proposta. Uma recusa do servidor nunca aparece como sucesso.
- R9 (parent R34) Fato observado e diagnóstico são distinguíveis. Espera, revisão e incerteza têm mensagens distintas. Falha do Provedor e ausência de dados têm apresentação própria.
- R10 (parent R37) As fixtures do protótipo usam os nomes, estados, Ações e códigos de erro de `contracts/openapi-signalnoir.yaml`. Uma divergência encontrada vira proposta de mudança de contrato em B03, nunca ajuste silencioso.
- R11 (parent R41) B01 fixa: - a separação entre ajuste e teste; - o Gabarito prévio, inclusive os casos em que `REQUEST_REVIEW` é o correto; - os negativos de mapeamento, identidade e Recibo; - a regra de novo episódio.

## Constraints

- Tudo aqui é preparação (contratos, especificação, fixtures, spike). Nenhum código da submissão antes de 26/10, e o spike fica fora do repositório (parent Constraints; PRD Q-1).
- Contrato antes do código, spine antes do contrato (AD-16): a mudança de identidade (R5 aqui) atualiza o AD-21 antes do OpenAPI.

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

- Decision (21/10): o épico não espera o protótipo como um todo. Só a entrada 5 (B03) depende dele (`after` da entrada); a dependência fica declarada no `tickets.toml` da iniciativa com esse escopo. As entradas 1 e 2 começam já.
- Decision (21/10): refinado só com as linhas da iniciativa (uma linha por id pai). Nenhuma decisão de produto nova.
- Decision (21/10): o tracer bullet é o spike do build 154 (entrada 1), porque é a parte menos certa e decide o modo da Investigação (FR-53) para os outros épicos.
- Decision (21/10): sem "Refactor sweep". O épico só produz contratos, especificação e um spike descartável; não há código para varrer.
- Open question: API-Q11, a chave do efeito deixa de depender de `proposalId`? Decisão de José com Henry, dentro da entrada 3.
- Open question: Q-3 (Provedor e modelo de referência), Q-5 (IRIS ou IRIS for Health) e Q-A a Q-F da arquitetura. Respondidas pelo spike (entrada 1).
- Open question: Q-10, cinco variantes de teste por Família cabem na capacidade? Henry decide na entrada 4.

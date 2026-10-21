---
type: reconcile
date: 2026-10-20
inputs:
  - Sentai-Nexus-proposta-Musketeers.pdf (16/10/2026, 7 páginas, fora do repositório)
  - signal-noir-revisao.html (caderno de decisão, 19/10/2026, fora do repositório)
against: [prd-signal-noir/prd-signal-noir.md, prd-signal-noir/addendum.md, architecture-signal-noir/architecture-signal-noir.md]
---

# Reconciliação das fontes: proposta de 16/10 e caderno de 19/10

## 1. O que cada fonte contribui

| Fonte | Papel | Situação |
|---|---|---|
| Proposta de 16/10 (PDF) | Recorte original do Sentai Nexus: 4 situações limpas, 4 Ações, arquitetura conceitual da Production, reuso do SentaiTask, backlog N01–N13, cronograma, frentes, System 1 opcional, roteiro de 6 momentos e definição de pronto. | Já absorvida pelo PRD de 18/10 (§1, §9, §11; addendum §A e §B). Nada material ficou de fora. |
| Caderno de 19/10 (HTML) | Consolidação depois do PRD e da arquitetura: MVP menor, 12 ADRs de planejamento, backlog B01–B14 com critérios de aceite, desenho do benchmark, marcos com corte e 7 questões para Henry e José. | É a fonte mais recente. Ainda é uma proposta, não aprovada pela equipe. Foi distilada na iniciativa. |

## 2. Itens da proposta de 16/10 superados

| Proposta de 16/10 | Hoje | Onde |
|---|---|---|
| REST + SSE na interface | Polling incremental, com SSE adiado | AD-17; caderno ADR-09 |
| Canvas Svelte Flow | Fora da submissão | caderno §02 |
| Marco de 25/10: "agente chamado pela Production e decisão persistida" | Spike descartável em 25/10 e menor prova em 27/10 | PRD §9.4; caderno §07 |
| System 1 como P2 | Fora da submissão | PRD §9.3; caderno §02 |
| N13: protocolo adicional | Fora (v2) | PRD §9.3 |
| Henry "mantém o simulador" junto com a frente IRIS | Henry é o responsável explícito, com regra de redistribuição antes de 26/10 | caderno §01, §05 |

## 3. Divergências entre o caderno de 19/10 e o PRD e a arquitetura

| Tema | PRD / arquitetura | Caderno de 19/10 | Na iniciativa | Ação pendente |
|---|---|---|---|---|
| Núcleo | P1, P3, P5, P8 e P9 no núcleo | P5/P8b + P13 no núcleo; P3 e recuperação obrigatórios; P9 condicionado; P1 como variante | R1–R5 | Atualizar PRD §9 |
| Meta de sucesso | SM-1: ≥ 80% com margem de 30 pontos | Ganho medido, sem meta de vitória | R6 | Reescrever SM-1 no PRD |
| Execução de Referência | P5, P8, P9 e P1; k = 3 | P5 e P8b; 5 × 3 = 30 investigações, mais controles e Dossiê | R43 | PRD FR-39/FR-40; Q-10 |
| Idempotência | `idempotencyKey` por Pedido e Ação (FR-22, AD-21) | `commandId`, `executionId` e `businessEffectKey`; Parceiro deduplica chave + payload | R24–R26 | Atualizar AD-21 e `openapi-sim.yaml` |
| Expiração da Aprovação | Expira por prazo ou por Evidência que contradiga pré-condição (FR-18) | Prazo e Revalidação; sem expiração genérica por qualquer Evidência | R22 | Ajustar a redação de FR-18 |
| Provedores | Configurável entre 4 (FR-50) | Um de referência; suporte aos 4 não garantido | R17 | Ajustar FR-50 e o README |
| Caso depois de estado terminal | Caso novo só com novo `orderId` ou após terminal (FR-3, assumption) | Novo episódio cria Caso relacionado | R10 | Registrar o vínculo no contrato (B01) |
| Saída de `HOLD` | Reavaliação periódica volta a `Investigating` (FR-51) | Saída exige nova Investigação e, quando aplicável, nova Aprovação | R10, R19, R27 | Compatível; confirmar em B01 |
| Independência do benchmark | Regras escritas por quem não escreveu o Gabarito (FR-48) | Henry: reservados; José: baseline; Henrique: avaliador | R46 | Compatível |
| Instalação cruzada | "Outro integrante" | Henrique como responsável (B13) | Constraints | — |
| Lease e outbox | AD-20, AD-22 | Lease com identidade de posse e de geração; cursor por confirmação | R28 | Conferir AD-22 em B06 |

## 4. Acréscimo de 20/10: protótipo da solução

O caderno não previa protótipo. A pedido de Henrique, a iniciativa ganha os requisitos R36–R39 e o épico `epic-prototipo-solucao`: um protótipo descartável em HTML, CSS e JS puros, antes de 26/10, que dá ao time uma noção da solução final e alimenta B03.

A regra de construção durante o concurso (Q-1) impõe três salvaguardas:
- o protótipo não é código da submissão;
- ele fica fora de `ui/` e da imagem;
- ele sai do repositório se o esclarecimento do edital exigir.

## 5. Questões levadas à iniciativa

As 7 questões da revisão do caderno (§08) e as questões do PRD ainda abertas estão em Notes do ticket da iniciativa.

## 6. Atualização de 21/10

Depois do merge do PR #1, o PRD foi atualizado no branch `prd-update-caderno-19-10`. Situação das ações pendentes da §3:

| Tema | Situação |
|---|---|
| Núcleo | Resolvido: PRD §9, com o recorte de 19/10, §9.1 e §9.2 (P9 condicional) |
| Meta de sucesso | Resolvido: SM-1 sem meta de vitória |
| Execução de Referência | Resolvido: FR-39, FR-40 e FR-49 |
| Expiração da Aprovação | Resolvido: FR-18 |
| Provedores | Resolvido: FR-50 |
| Caso depois de estado terminal | Resolvido: FR-3 (Caso relacionado). O vínculo no contrato fica para o B01 |
| Idempotência | Em aberto: API-Q11 do contrato (PR #2), decisão de José. AD-21 e FR-22 não foram alterados |
| Saída de `HOLD` e lease | Contrato draft.2 (PR #2): `leaseGeneration`. Conferir o AD-22 em B06 |

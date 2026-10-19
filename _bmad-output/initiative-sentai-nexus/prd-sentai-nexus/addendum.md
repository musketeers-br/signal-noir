# Addendum: Sentai Nexus PRD

Este addendum reúne material técnico e de apoio para a arquitetura, a UX e a implementação, que não cabe no corpo do PRD. Os termos seguem o Glossário do PRD (§3).

## A. Mapeamento conceitual para componentes IRIS (proposta de 16/10)

Os nomes são conceituais e ficam no namespace `Nexus`. As interfaces só devem ser consolidadas depois da prova do build 154.

| Camada | Responsabilidade | FRs |
|---|---|---|
| OrderIntake (Business Service) / OrderWorkflow (Business Process) | Receber, validar estrutura e correlacionar; acompanhar entrega e Exceção | FR-1 a FR-4 |
| AgentDecision (Business Operation com AI Hub) / InvestigationTools | Investigação, Ferramentas restritas, orçamento, Provedor configurável, Evidência Pré-coletada | FR-9 a FR-13, FR-50, FR-53 |
| Decision.Validator / Approval.Service | Validação, roteamento, confirmação de Recibo anterior, Aprovação, validade | FR-14 a FR-19, FR-47 |
| PartnerDelivery (Execution BO) / modelos persistentes | Revalidação, Execução idempotente, Reconciliação, Reavaliação, histórico do Caso | FR-20 a FR-24, FR-51 |
| Simulador (Parceiro Simulado, Origem simulada, fontes de Evidência) | Cenários, falhas controladas, Recibos, status na Origem | FR-30 a FR-33 |
| Modo Regras / executor do Benchmark | Linha de base determinística, Modo Benchmark, relatório, validação rápida | FR-39 a FR-41, FR-48, FR-49 |
| Interface + API de Casos (REST + SSE) | Lista, detalhe, Aprovação, Dossiê, Visual Trace | FR-34 a FR-38 |

**Fronteira de arquitetura:**
- O fluxo é executado pela Production nativa.
- O executor WQM do SentaiTask **não** vira segunda camada de orquestração.
- O WaveDispatcher serve apenas de referência de controles.
- Nenhum objeto de Agente em memória pode ser o único estado durável.

## B. Padrões reaproveitados do SentaiTask (Q-2 resolvida: padrões reescritos a partir de 26/10, sem copiar código)

| SentaiTask | Uso no Nexus | Adaptação |
|---|---|---|
| SvelteKit / Svelte Flow | Estrutura visual e canvas | Casos, decisões, evidências, aprovação |
| REST + SSE | Atualização da interface | Contratos próprios do domínio Nexus |
| FlowValidator | Validação centralizada | Regras de Propostas e Ações |
| StepType | Catálogo compilado | Catálogo fechado de Ações |
| RunNarrator | Linha do tempo de fatos | Registro obrigatório de eventos críticos |
| IDs de execução | Correlação | Caso, mensagem, Proposta, Aprovação, Tentativa |
| Testes e fixtures | Verificação | Cenários de Agente, Parceiro e Aprovação |
| Docker e build da UI | Empacotamento | Load/retag do build 154, instalação limpa |

## C. Contrato do Caso (rascunho de campos)

Estes campos são ponto de partida para a arquitetura, não um schema final.

- **Caso:** `caseId`, `orderId`, `correlationIds{message, transactionIds[], attempts[]}`, `partnerId`, `state`, `exceptions[]`, `currentProposalId`, `createdAt`, `updatedAt`, `synthetic: true`, `replay: bool`, `benchmarkMode: bool`.
- **Exceção:** `exceptionId`, `httpStatus`, `body`, `observedAt`, `attemptId`.
- **Snapshot do Pedido:**
  - o payload original é imutável;
  - a Chave de Equivalência (`patientId`, `examCodes[]`, `collectedAt`, `specimenId`) é calculada na entrada;
  - depois de `APPLY_APPROVED_MAPPING`, o payload transformado é guardado separado, com referência ao Mapeamento.
- **Evidência:** `evidenceId`, `source` (Ferramenta ou sistema), `params`, `result` (bruto, por valor), `observedAt`, `suspicious: bool`, `obsoletedBy?`.
- **Proposta:** `proposalId`, `version`, `author` (agent, rules ou operator), `diagnosis{summary, claims[{text, evidenceIds[]}], hypotheses[{text, status: chosen|discarded, reason}]}`, `action`, `params`, `scope` (single_case na v1), `confidence` (ALTA, MEDIA ou BAIXA), `preconditions[{check, expected}]`, `priorReceiptCandidate?`, `versions{policy, prompt, model, provider}`, `metrics{durationMs, toolCalls, tokensIn, tokensOut, estCostUsd}`.
- **Decisão do Validador:** `proposalId`, `version`, `verdict` (accepted, blocked, review ou prior_receipt_confirmed), `reasons[]`, `requiresApproval`.
- **Aprovação:** `approvalId`, `proposalId`, `version`, `decision` (approved ou denied), `by` (operador ou `benchmark`), `at`, `expiresAt`.
- **Execução:** `executionId`, `approvalId`, `idempotencyKey`, `revalidation{passed, checks[], at}`, `authorizedAt`, `attempts[]`, `outcome`.
- **Recibo:** `receiptId`, `orderId`, `idempotencyKey`, `receivedAt`.
- **Dossiê:** `reason`, `partialDiagnosis`, `hypotheses[]`, `conflicts[]`, `collidingRecords[]`, `unconfirmedCandidates[]`, `suggestedNextStep`.
- **Evento da Linha do Tempo:** `seq`, `at`, `type`, `actor`, `refId`, `payload`.

## D. Transições de estado (rascunho)

| De | Para | Gatilho |
|---|---|---|
| — | Open | 1ª Exceção do Pedido (FR-3) |
| Open | Investigating | Caso encaminhado à Investigação |
| Investigating | DecisionProposed | Proposta recebida |
| Investigating | ReviewRequired | Orçamento excedido, resposta inválida, Provedor indisponível ou investigação interrompida por reinício (FR-4) |
| Investigating / DecisionProposed | ResolvedByPriorReceipt | Validador confirma a Chave de Equivalência com um Recibo anterior (FR-47) |
| DecisionProposed | PendingApproval | Validador aceita e exige Aprovação |
| DecisionProposed | Executing | Validador aceita sem Aprovação (`HOLD`) |
| DecisionProposed | ReviewRequired | Validador bloqueia, falta Evidência, Confiança BAIXA ou Recibo candidato não confirmado |
| PendingApproval | Approved / Rejected | Decisão do Operador ou Aprovação Automática de Benchmark |
| Rejected | Investigating | 1ª negação: nova Investigação, com o motivo como Evidência (FR-5) |
| Rejected | ReviewRequired | 2ª negação (FR-5) |
| Approved | Executing | Revalidação passou |
| Approved | Held | Revalidação: Parceiro instável ou janela de manutenção |
| Approved | Cancelled | Revalidação: Pedido cancelado na Origem |
| Approved | PendingApproval | Aprovação expirada ou Evidência contradiz pré-condição (FR-18) |
| Executing | Held | Execução de `HOLD` |
| Executing | Resolved | Recibo válido, ou Reconciliação encontra Recibo após timeout |
| Executing | Failed | Tentativas da Política esgotadas |
| Held | Investigating | Reavaliação indica que a condição de espera acabou (FR-51) |
| ReviewRequired | DecisionProposed / Cancelled | Ação do Operador (FR-29) |
| qualquer não terminal | Investigating | Nova Exceção do mesmo Pedido, registrada no Caso (FR-3) |

## E. Especificação das Famílias de Cenários sujos

A coluna "regra ingênua" é só **ilustração** do tipo de heurística que a Família quebra. O Benchmark compara com o **Modo Regras** (FR-48), que é a melhor linha de base possível com as mesmas Ferramentas. Nas Famílias de Decisão do Agente, o Gabarito deve incluir variantes em que o Modo Regras forte acerta, para que o placar não seja inclinado.

**Decisão do Agente**

| Família | Cenário no Simulador | Regra ingênua (ilustração) | Desfecho correto |
|---|---|---|---|
| P1 (variante de P5) | Timeout de ~90 s na 1ª Tentativa e 500 com erro semântico na 2ª | timeout → RETRY | Diagnóstico semântico; mapeamento aplicável ou revisão |
| P5 | HTTP 500 com erro de validação no corpo; 200 com rejeição em texto livre; redação PT/EN variada | 5xx → RETRY; 200 → sucesso | Diagnóstico de erro de negócio; mapeamento ou revisão |
| P8a | Healthcheck UP, mas 100% de timeout nos logs recentes | Confia no healthcheck → RETRY | HOLD |
| P8b | Dois Mapeamentos Aprovados para o mesmo código, distinguíveis só pelo contexto do Pedido (tipo de amostra, unidade) | Aplica o 1º mapeamento | Mapeamento correto pelo contexto, ou revisão se o contexto faltar |
| P9 | Código válido. A Origem reenviou o pedido com outro Identificador de Transação e outro `orderId`, e há Recibo de 3 min antes com a mesma Chave de Equivalência | código válido → RETRY | ResolvedByPriorReceipt confirmado pelo Validador. Sem equivalência: revisão |

**Garantias da Plataforma**

| Família | Cenário no Simulador | Comportamento exigido |
|---|---|---|
| P3 | Depois de Approved, o Parceiro volta a falhar, entra uma janela de manutenção ou o Pedido é cancelado na Origem | Held / Cancelled, sem efeito |
| Idempotência | Timeout com Recibo perdido; reinício durante Executing; Aprovação repetida | 0 Recibos duplicados |

**Variantes:**
- mudam Parceiro, códigos, tempos, redação dos erros (PT/EN) e ordem das Evidências;
- conjuntos de ajuste e de teste são separados;
- o teste tem pelo menos um Parceiro e um padrão de redação que não aparecem no ajuste.

**Teste de instrução embutida (FR-13):** numa variante de P5, o corpo traz uma instrução maliciosa. O desfecho deve ser igual ao da mesma variante sem a injeção.

## F. Roteiro da demo (versão detalhada)

1. **Contraste limpo (10–15 s):** regra e Agente iguais. "Se o simulador só gerar falhas simples, IA não prova nada."
2. **P1 → P5 + P8b:** timeout, depois 500 com corpo semântico, depois dois mapeamentos possíveis. "A superfície diz uma coisa; as evidências, outra." O Caso aparece em camadas: Evidências, Diagnóstico, Ação, Escopo, Confiança e hipótese descartada.
3. **P9:** "Não é só classificar erro; é descobrir que o problema já não existe." O Validador confirma a Chave de Equivalência.
4. **P3:** "Aprovação não congela o mundo." A Revalidação bloqueia uma execução vencida.
5. **Limite:** a identidade ambígua permanece em revisão, com o Dossiê na tela.
6. **Resiliência:** aprovar duas vezes não duplica o efeito; o Recibo é único.
7. **Benchmark honesto:** a Execução de Referência mostra a parte "Decisão do Agente" com faixas, a parte "Garantias da Plataforma" como aprovado/reprovado e o empate no limpo.

O caso "código desconhecido → mapeamento aprovado único" serve só como contraste limpo ou como fallback se a demo principal falhar.

## G. Insights do brainstorming que orientam decisões

- **Uma só ideia.** Diagnóstico separado, Escopo explícito e Incidente são a mesma ideia: a saída do Agente é um diagnóstico estruturado e o Catálogo continua fechado. Na v1 o Escopo é sempre `single_case`; os Incidentes ficam para a v2.
- **O diferencial mora no Simulador.** A frente de Cenários é caminho crítico.
- **Dossiê de Revisão.** É a vitória mais barata do mundo sujo.
- **Revalidação (P3).** Vem quase de graça dos controles herdados e é uma Garantia da Plataforma, não mérito do Agente.
- **Confiança como roteadora.** Abaixo do limiar, o Caso vai para revisão. A calibração é medida (SM-7).
- **Variantes, não um caso.** Um placar com um caso por Cenário é anedota; cada Família precisa de variantes.

## H. Revisão de 18/10: achados aplicados

- **Fontes:** `reconcile-proposta.md`, `reconcile-intencao.md`, `reconcile-edital.md`, `review-rubric.md` e `review-adversarial-general.md`.
- **Blocos aplicados:**
  - A, benchmark: Modo Regras forte, relatório em duas partes, Execução de Referência, validação rápida, contramétricas, calibração.
  - C, governança: FR-47 e Chave de Equivalência.
  - D, demo e jornadas: UJ-1 coerente com P8b; momentos Limite e Resiliência; versão sem P2.
  - E, edital: FR-50, FR-52, README, votação, horário em BRT.
  - F, proposta: riscos, revisão cruzada, System 1 como terceiro braço, definição de pronto.
  - Mecânica.
- **Bloco B (cortes de escopo), aplicado depois de aprovado pelo usuário:**
  - Incidentes e P2 fora;
  - Fases fora;
  - sem autenticação;
  - Replay restrito à referência;
  - Evidência Pré-coletada como plano B (FR-53);
  - spike descartável em 25/10 e menor prova em 27/10.

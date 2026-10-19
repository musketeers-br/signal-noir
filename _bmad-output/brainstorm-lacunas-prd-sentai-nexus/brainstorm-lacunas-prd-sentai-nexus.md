# Sentai Nexus — Intenção para o PRD (fechamento das 6 lacunas)

> Origem: sessão de brainstorming de 18/10/2026 sobre a proposta *Sentai-Nexus-proposta-Musketeers.pdf* (16/10/2026). Os dados são todos sintéticos (pedidos JSON e parceiro HTTP simulado). Os números marcados com **(?)** são estimativas que ainda faltam validar.

## 1. Tese e objetivo

- **Tese do diferencial:** o agente **empata com as regras no mundo limpo e se diferencia no mundo sujo**. Num simulador limpo (erros sinceros, evidência completa, uma causa por falha, gabarito único), Regras e Regras+Agente empatam em 100% e o catálogo fechado vira automação determinística com custo extra.
- **Princípio do simulador:** ele não gera variações cosméticas de erro. Gera estruturas de decisão que quebram heurísticas locais: decisões não locais, evidência imperfeita e contexto que muda.
- **Objetivo da competição:** demonstrar a decisão contextual de um agente do IRIS AI Hub (build 154) dentro de uma Production IRIS. O percurso deve ser completo, reproduzível (Docker a partir do README, critério inegociável) e fácil de avaliar.
- **Objetivo do produto:** levar uma exceção interrompida a uma resolução rastreável e verificável, apoiada nos controles herdados do SentaiTask.
- **Invariantes de governança:**
  - A IA propõe e a aplicação governa.
  - O catálogo de ações é fechado: RETRY, APPLY_APPROVED_MAPPING, REQUEST_REVIEW e HOLD.
  - Mensagens e logs são dados potencialmente hostis, nunca instruções.
  - Fail-safe: qualquer anomalia do LLM leva a REQUEST_REVIEW.
  - Idempotência é obrigatória.
  - O agente não tem estado em memória: tudo é persistido antes de qualquer efeito externo.
  - Não há inferência clínica.

## 2. Lacuna 1 — Capacidades distintivas e cenários sujos

**Na submissão:**

| ID | Cenário no simulador | Capacidade do agente | Como a regra ingênua erraria |
|---|---|---|---|
| **P2** | 20 a 40 mensagens do mesmo parceiro ou lote falham em 3 min | Correlaciona a janela recente e recomenda HOLD em lote ou incidente | 30 RETRYs individuais, ou seja, uma tempestade de retries |
| **P3** | Healthcheck passa de DOWN a UP mas o erro segue alto; ou entra manutenção; ou o pedido é cancelado na origem | Avalia a tendência e condiciona a ação a pré-condições verificáveis na execução | Decide e executa com um snapshot obsoleto |
| **P5** | HTTP 500 para erro de validação de negócio; 200 com rejeição em texto livre | Ignora o status HTTP e interpreta o corpo | RETRY indevido e falso sucesso registrado |
| **P8** | Healthcheck UP com 100% de timeout nos logs; 2 mapeamentos aprovados distinguíveis só pelo contexto | Pondera a confiabilidade das fontes e desambigua por outros campos (idade, coleta, unidade) | Confia na 1ª fonte ou aplica o 1º mapeamento |
| **P9** | Código válido, depois pista de duplicidade, depois recibo de 3 min antes com outro ID | Investigação multi-hop por hipóteses | Para em "código válido → RETRY" e reprocessa algo já entregue |
| P1 *(opcional, variação embutida (?))* | Timeout de 90 s mais código fora do catálogo | Checa a integridade semântica do payload antes de um RETRY | Gasta tentativas e mascara a causa semântica |

**Ganho barato fora da tabela:** P13, o dossiê de revisão (ver a seção 9).

**Fora da submissão:**
- P4, nó corrompido upstream, e P7, pista em texto livre: ficam para um artigo.
- P6, P11, P10 e P12. A priorização preliminar pôs P10 e P12 na faixa B (mais infraestrutura) e P6 e P11 na faixa C.

## 3. Lacuna 2 — Contrato mínimo do Caso

- **D1. O que é o Caso:** a unidade durável de resolução de uma exceção operacional, ligada a uma mensagem ou pedido correlacionado num ponto de falha.
  - É o contêiner de tentativas e execuções, e não se confunde com nenhuma delas.
  - MVP: 1 pedido sintético com 1 exceção principal por vez.
- **D2. Fonte de verdade:** um modelo persistente próprio do Nexus na Production.
  - A fonte de verdade não é a UI, nem o estado do agente, nem só o Visual Trace.
  - Visual Trace, logs e respostas de ferramentas entram como evidência referenciada ou anexada.
- **D4. Campos mínimos:**
  - CaseId e CorrelationIds
  - snapshot do pedido e falha inicial
  - evidências e diagnóstico
  - ação proposta, scope e confiança (?)
  - estado, aprovação, execução e recibo/reconciliação
  - timeline
  - versões de política, prompt e modelo

  O resto fica fora do schema inicial.
- **D5. Camadas explícitas:** fatos e evidências observadas → **diagnóstico operacional** → **decisão proposta** (ação do catálogo + parâmetros + **scope**) → aprovação → execução e resultado.
  - O diagnóstico é estruturado e separado da ação. Exemplo: ação HOLD com o diagnóstico "degradação sistêmica do parceiro".
  - O scope pode ser `single_case`, `batch` ou `queue_segment`. É uma recomendação sistêmica opcional e não cria verbo novo.
- **D7. Projeções:** um único Caso canônico, com três projeções: UI operacional, export de benchmark reproduzível e visão resumida para a demo.

## 4. Lacuna 3 — Ciclo de vida e o que falta segundo o stress test

- **D3. Nascimento:** o Caso nasce na 1ª exceção operacional relevante, depois da correlação.
  - Tentativas, evidências, aprovação, execução e reconciliação enriquecem o mesmo Caso.
  - Só se abre um Caso novo para uma nova mensagem distinta ou para um episódio independente. O critério exato está em aberto.
- **D6. Ciclo mínimo:** `Open → Investigating → DecisionProposed → PendingApproval → Approved/Rejected → Executing → Resolved | Held | ReviewRequired | Failed(?)`.
  - Os detalhes ficam na timeline.
  - A reabertura entra como evento ou transição posterior.

**Peças que faltam, reveladas pelo teste do D6 contra os cenários sujos:**

| Cenário | Onde a máquina trava | Requisito novo |
|---|---|---|
| P2 | Open/Investigating → DecisionProposed. A máquina só enxerga o caso unitário. | Uma entidade **Incidente/Lote** e um evento de correlação sistêmica, para um controlador segurar N Casos de uma vez sem N chamadas ao agente |
| P3 | Approved → Executing. A aprovação fica velha antes do efeito externo. | Um evento de **revalidação pré-execução**, com transição para Held ou Failed/Cancelled (?) quando o parceiro cai ou o pedido é cancelado |
| P9 | Dentro de Investigating. Um recibo prévio com outro ID muda o Caso. | Um evento de **deduplicação/reconciliação por correlação tardia** e talvez um estado terminal **ResolvedByPriorReceipt** (?) |

## 5. Lacuna 4 — Avaliadores e demo

**Quem avalia:** júri técnico InterSystems (ou curadoria) e a comunidade, que vota até 15/11. Os pesos do edital não estão confirmados (?).

| Avaliador | JTBD |
|---|---|
| Júri técnico | Em 4 min, com README reproduzível, provar que o AI Hub é usado de verdade dentro da Production e muda o resultado do workflow, com aprovação, idempotência e rastreabilidade sérias. Não pode parecer um chat acoplado a uma automação trivial. |
| Comunidade | Entender rápido por que é útil, diferente e confiável; ver uma IA resolvendo um problema operacional real sem parecer perigosa nem artificial. |

**Mudança de roteiro:** a demo **não abre** com "código desconhecido → mapeamento aprovado". É justamente o caso em que a regra resolve igual, o que contradiz o JTBD do júri. Esse cenário fica, no máximo, como contraste limpo ou fallback.

**Espinha da demo:** abrir com um erro que parece simples, provar que não é, mostrar o Caso estruturando a descoberta, impedir uma execução errada causada por mudança de contexto e fechar com evidência de que o resultado muda onde as regras falham.

**Versão enxuta de 4 min, com 6 momentos:**

| # | Momento | Cenário | Mensagem |
|---|---|---|---|
| 1 | Contraste: mundo limpo empata | limpo | 10 a 15 s em que regra e agente dão a mesma resposta |
| 2 | Caso principal | P5+P8 | "A superfície diz uma coisa, as evidências outra" |
| 3 | Investigação iterativa | P9 (+P1) | Em vez de RETRY de cara, mostra por que a 1ª hipótese caiu |
| 4 | Decisão estruturada | — | Evidências, diagnóstico, ação, scope e confiança separados |
| 5 | Reviravolta | P3 | "Aprovação não congela o mundo": a revalidação bloqueia uma execução velha |
| 6 | Benchmark honesto | todos | Regras vs agente. A rajada P2 aparece como flash de 15 s (?) na mesma tela. |

A versão estendida tem ainda M6 (P9 reconciliado sem reexecutar) e M7 (P2 como momento próprio).

## 6. Lacuna 5 — NFRs numéricos

| NFR | Meta |
|---|---|
| Orçamento por investigação | ≤ 4 chamadas de ferramenta e ≤ 20 s. Acima disso, REQUEST_REVIEW. |
| Latência da exceção até a proposta validada | p50 18 s / p95 45 s (?) |
| Latência com aprovação humana | p50 35 s / p95 90 s (?) |
| Custo por Caso resolvido com agente | US$ 0,01 a 0,04 (?). Regras têm custo marginal perto de zero. |
| Placar do benchmark | Empate no limpo. Nos 5 sujos: regras 2/5 contra agente 4/5 em resolução correta, e 1/5 em revisão segura (estimativa) |
| Benchmark | Várias variantes por família de falha, separadas por famílias, parceiros e padrões. Um caso por cenário é anedota. |

## 7. Lacuna 6 — Marcos com critério e corte

| Marco | Critério de saída | Corte se atrasar |
|---|---|---|
| **25/10, menor prova** | Um pedido sintético entra na Production e a exceção abre um Caso persistido. O BO chama de fato o AI Hub build 154. O agente consulta ao menos 1 ferramenta e devolve uma proposta do catálogo. A proposta fica persistida com evidência e é recuperável após reinício. *Desejável:* a ferramenta devolver um erro mentiroso (P5). | Sem essa prova, abandonar múltiplos cenários, UI rica, benchmark comparativo e a narrativa de agente operacional até ela passar |
| **29/10** | Um Caso real de ponta a ponta na UI (falha, evidências, investigação, proposta validada, aprovação, execução, resultado) em ao menos 1 cenário sujo principal. É também a data da integração real UI/simulador com o backend. | Cortar System 1, P2, cenários simultâneos e refinamento visual. Manter só a trilha mais forte. |
| **02/11** | Aprovação durável da versão exata, revalidação pré-execução, execução com chave de idempotência e reconciliação por recibo ou timeout, incluindo P3 | Execução automática só para uma ação comprovada. O resto roda em modo demonstrativo, com bloqueio seguro antes do efeito externo. |
| **05/11, freeze** | Benchmark reproduzível com os 5 cenários sujos, Caso canônico persistido, demo de 6 momentos ensaiável e métricas de latência, custo e placar | P2 deixa de ser momento próprio. Reduzir a 3 cenários fortes (P3, P5/P8, P9), sem comparação ampla. |

**Datas finais:** a submissão é em 08/11 (07/11 submetível, 08/11 é só margem) e a votação vai até 15/11.

**Divisão das frentes:**
- José Roberto: IRIS e AI Hub.
- Henrique: UI.
- Henry: produto, simulador, benchmark e submissão.

**Caminho crítico:** a frente do simulador. Os cenários sujos precisam ser um contrato fechado com a frente IRIS entre 16/10 e 25/10.

## 8. Fora de escopo da submissão

- System 1 em sombra (só entra se provar ganho no benchmark sem afetar o P0)
- HL7/FHIR (P2)
- Busca semântica
- Múltiplos provedores ou modelos
- Canvas genérico
- Diagnóstico de nó corrompido (P4)
- Documentação não estruturada (P7)
- Ações fora do catálogo fechado
- Inferência clínica

## 9. Insights da síntese que afetam requisitos

- **Uma ideia só:** diagnóstico separado (D5), scope explícito e a entidade Incidente/Lote são a mesma ideia. A saída do agente é um diagnóstico estruturado e o catálogo de 4 ações continua fechado. Isso resolve a tensão com P2 e P4 sem abrir o catálogo.
- **O diferencial mora no simulador:** a frente de Henry (simulador, fixtures, benchmark) é caminho crítico da tese.
- **Dossiê de revisão (P13), a vitória mais barata:** transforma o fail-safe REQUEST_REVIEW em feature de valor e funciona mesmo quando o agente não decide.
  - O dossiê traz cadastros colididos, campos divergentes, o que já foi descartado e o próximo passo humano.
  - A qualidade do handoff pode virar métrica do benchmark.
- **Revalidação P3 quase de graça:** ela já faz parte dos controles obrigatórios herdados do SentaiTask (aprovação da versão exata + revalidação).
- **Risco no 25/10:** a menor prova só exercita o caminho limpo. Se possível, injetar P5 na ferramenta já nessa prova.
- **Risco no placar:** 4/5 contra 2/5 com um caso por cenário é anedota. São necessárias variantes por família.
- **Confiança vira roteadora:** abaixo de um limiar, o Caso vai para ReviewRequired. Isso justifica persistir a confiança mesmo com um validador determinístico.

## 10. Questões em aberto para o PRD

1. **Caso novo ou mesmo Caso:** qual o critério? Nova falha do mesmo pedido gera nova fase, Caso filho ou Caso novo?
2. **Confiança:** formato (float 0-1, ALTA/MÉDIA/BAIXA ou score do validador), o que ela mede e qual o limiar de roteamento para ReviewRequired.
3. **Estados terminais:** Failed, Cancelled e ResolvedByPriorReceipt entram? Quais são as transições da revalidação pré-execução?
4. **Modelo Incidente/Lote:** quem decide passar de mensagem para lote, e como um scope coletivo bloqueia e libera pedidos sem duplicar chamadas ao agente?
5. **Edital:** quem avalia, critérios e pesos entre júri e votação. Ainda não verificado.
6. **P1:** entra na submissão como variação embutida?
7. **P2:** é flash de 15 s ou momento próprio da demo?
8. **NFRs com (?):** validar latências p50/p95, custo por Caso e o placar-meta com medição real no build 154.
9. **Data do freeze:** a decisão de marco diz 05/11; uma nota do backcasting fala em "freeze 07/11" (07/11 = submetível). Confirmar.
10. **Pendências do Starbursting:**
    - dono do Caso e herança em troca de turno ou reinício
    - perfis de visibilidade
    - TTL da aprovação
    - critério de "resolvido" (200, confirmação assíncrona ou validação pós-entrega)
    - definição formal de recibo e equivalência para idempotência
    - payload original vs transformado em APPLY_APPROVED_MAPPING
    - mensagens em HOLD: na fila IRIS suspensa ou só no Caso
    - concorrência entre aprovações e retries simultâneos
    - reconstrução do estado após reinício do container
    - divergência entre a Production e o estado do Nexus
    - como o operador resolve um REQUEST_REVIEW (escolher ação, editar ou cancelar)
    - como distinguir replay de execução real na demo e no benchmark
11. **Risco técnico:** o build 154 (EAP) permite um agente dentro de um BO? É o objeto da prova de 25/10.

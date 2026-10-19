---
title: 'Revisão adversarial do spine — Signal Noir'
target: ../architecture-signal-noir.md
lens: 'duas unidades que obedecem a todos os ADs ao pé da letra e ainda assim constroem de forma incompatível'
date: '2026-10-19'
verdict: 'Não pronto para virar substrato de build: os ADs dizem "o quê" proteger, mas deixam abertos os pontos de costura entre Application, Production e HTTP, onde estão os buracos.'
counts: { critical: 6, high: 7, medium: 7, low: 4 }
---

# Revisão adversarial — Architecture Spine Signal Noir

**Veredito.** O spine acerta a tese central (núcleo puro, mutação única, Execução única, Simulador externo), mas não fecha as costuras: não define a fronteira transacional entre o commit do Caso e o envio do comando à Production, nem quem é o dono de cada transição. Também deixa abertos a derivação da Chave de Idempotência, a relação entre timeouts e o sweeper, como Evidências convivem com o `caseVersion` e de onde vem o Modo Benchmark. Em todos esses pontos, José (IRIS/AI Hub), Henrique (UI) e Henry (Simulador/Benchmark), ou dois agentes de código, podem seguir os 19 ADs ao pé da letra e mesmo assim entregar peças que não encaixam.

**Unidades usadas nos ataques:**
- **IRIS:** BS, BP, Agent BO, Execution BO e Tools, de José.
- **API/UI:** de Henrique.
- **Sim/Bench:** de Henry.
- **Agente A e Agente B:** dois agentes de código trabalhando em pacotes vizinhos.

**Contagem:** 6 críticos · 7 altos · 7 médios · 4 baixos.

---

## CRÍTICOS

### C-1. Dual-write entre o commit do Caso e o comando à Production (AD-2 × AD-6 × AD-4)

- **Unidade A (API, Henrique):** segue o AD-6 e faz `Application.Approve()`, que dá commit em `PendingApproval → Approved`. Depois entrega o comando ao BS de comandos. Se a Production estiver parada ou o `ProcessInput` falhar, o handler devolve 200, porque a transição já foi gravada.
- **Unidade B (IRIS, José):** também segue o AD-6, mas abre a transação, entrega o comando ao BS e só então faz commit. Assim, o BP pode reler o Caso (AD-4) antes do commit, ver o Caso ainda em `PendingApproval` e descartar o comando como "divergente".
- **Resultado:**
  - na ordem A, o Caso fica preso em `Approved` sem nenhum comando em voo;
  - na ordem B, o comando se perde porque foi lido antes do commit.
- **Lacunas no spine:**
  - O AD-8 manda varrer "Casos órfãos", mas não diz o que é órfão nem se o sweeper reenvia o comando.
  - O AD-6 não diz se `caseVersion` no comando é a versão de antes ou de depois da transição.

**Correção: novo AD-20 (Outbox de comandos).**
- O comando da Application grava, na mesma transação da transição e do evento, uma linha `CommandOutbox{commandId, caseId, caseVersionAfter, type, createdAt, dispatchedAt?}`.
- A entrega ao BS de comandos acontece só depois do commit e é feita por um único despachante.
- Esse despachante é chamado em dois momentos:
  - de forma síncrona, logo após o commit, como caminho rápido;
  - pelo sweeper, para linhas com `dispatchedAt` nulo há mais de N segundos.
- Para o BP, o comando é idempotente por `commandId` e carrega a **versão posterior** à transição.
- O BP descarta, com evento `command_stale` na Linha do Tempo, todo comando cujo `caseVersionAfter` seja diferente do `caseVersion` atual.
- Não existe envio a BS dentro de transação aberta.

### C-2. O passo "registro durável da autorização" contradiz a máquina de estados (AD-5 × addendum §D)

- **O conflito:**
  - O AD-5 manda gravar a autorização (1) antes da Revalidação (2).
  - O addendum §D diz `Approved → Executing` "quando a Revalidação passou".
  - Logo, a autorização é gravada com o Caso ainda em `Approved`, e o AD-2 proíbe gravar evento sem transição.
- **Agente A (Execution BO):** grava a autorização como `Approved → Executing`, criando `executionId`, e depois revalida. Se a Revalidação falhar, precisa fazer `Executing → Held` ou `Executing → Cancelled`. A segunda transição não existe na tabela.
- **Agente B (Core):** implementa a tabela do addendum ao pé da letra. Revalida em `Approved` e só depois transiciona. Com isso, a autorização vira uma escrita sem transição, que viola o AD-2, ou fica fora do Caso, o que viola o FR-21.
- **Efeito colateral:** com dois comandos `Execute` para o mesmo Caso (C-1, um reenvio do sweeper ou aprovação duplicada), na leitura B os dois BOs revalidam em `Approved` e os dois enviam, porque nenhum CAS separa o vencedor antes do efeito.

**Correção: AD-5 apertado.**
- O passo 1 é a transição CAS `Approved → Authorized`, um novo estado, ou `Approved → Executing`. Ela cria `Execution{executionId, approvalId, idempotencyKey}` na mesma transação. Só o vencedor desse CAS segue para os passos 2 a 4.
- A tabela §D passa a incluir:
  - `Executing → Held`, `Executing → Cancelled` e `Executing → PendingApproval` por falha de Revalidação;
  - ou, alternativamente, o estado `Authorized` com essas saídas.
- O Core precisa de uma tabela única e versionada, em `SignalNoir.Core`, que prevalece sobre o addendum.

### C-3. Derivação da Chave de Idempotência indefinida (AD-5 × FR-22 × AD-1)

- O FR-22 diz "estável por Pedido e Ação autorizada". O AD-1 diz que as regras de idempotência vivem no Core, mas nenhum AD define a fórmula.
- **Leitura A (Core, José):** `key = H(orderId, action)`.
  - Na P8b, a primeira Proposta aplica o Mapeamento errado, o Parceiro recusa, e a segunda aplica o certo. As duas são `APPLY_APPROVED_MAPPING` com o mesmo `orderId`, portanto a mesma chave.
  - O Parceiro Simulado (Henry), que deduplica por chave, devolve o Recibo da primeira, ou 409. Se a primeira não gerou Recibo, depende da implementação.
  - Numa sequência `RETRY → Held → Reavaliação → RETRY`, a mesma chave pode ser deduplicada contra uma tentativa que falhou.
- **Leitura B (Agente B):** `key = executionId`.
  - Na Aprovação repetida ou num reenvio do sweeper que gere um segundo `Execution`, ou seja, sem o CAS de C-2, nascem duas chaves e dois Recibos. Isso viola o SM-4.
- **Lacuna no spine:** nada diz o que o Parceiro faz com a mesma chave e um payload diferente.

**Correção: novo AD-21 (Chave de Idempotência).**
- Fórmula: `idempotencyKey = H(orderId, action, canonical(params), proposalId, proposalVersion)`. Ela é calculada no Core no passo 1 do AD-5 e é imutável dentro do `Execution`.
- Retry interno, reinício e Reconciliação reutilizam o mesmo `Execution` e a mesma chave.
- Uma nova Proposta gera uma nova chave.
- O contrato `/sim/api/v1` define três comportamentos do Parceiro:
  - mesma chave e mesmo payload: devolve o Recibo original com 200 e `replayed: true`;
  - mesma chave e payload diferente: devolve 422 `IDEMPOTENCY_KEY_REUSED`;
  - consulta por chave: `GET /receipts?idempotencyKey=`.

### C-4. Timeout HTTP × sweeper × CAS: o sweeper "resgata" um Caso que ainda está em voo (AD-8 × AD-5 × AD-3)

- **Unidade A (Execution BO, José):**
  - usa timeout HTTP de 90 s, o necessário para a P1 (timeout de cerca de 90 s);
  - depois faz Reconciliação;
  - faz até N tentativas da Política.
- **Unidade B (sweeper, Agente B):**
  - segue o AD-8 e trata como "vencido" um Caso em `Executing` há mais de 60 s, alinhado à cadência do FR-51;
  - move o Caso para `ReviewRequired`, como o FR-4 sugere para intermediários.
- **Sequência do conflito:**
  - O Parceiro grava o Recibo.
  - O BO tenta `Executing → Resolved` e falha no CAS (`STALE_VERSION`), então "registra e aborta", como diz o AD-3 para jobs internos.
  - Resultado: Recibo no Parceiro e Caso em revisão.
  - O Operador escolhe `RETRY` (FR-29). Pela C-3, nasce uma nova chave e um Recibo duplicado.
- **O mesmo vale para o Agent BO:** `Chat()` síncrono com 20 s de orçamento (NFR-1) e Provedores que demoram até 60 s (issue #37) contra um sweeper que considera `Investigating` vencido.
- **Lacuna no spine:** nenhum AD ordena os prazos, e a Configuração não lista timeouts.

**Correção: novo AD-22 (Lease de etapa).**
- Toda etapa assíncrona (Investigação, Execução) grava, no CAS de entrada, `stepLeaseUntil = now + maxDurationOfStep`, onde:
  - Execução: `maxDurationOfStep = Σ(timeouts HTTP × tentativas) + Reconciliação + margem`;
  - Investigação: `maxDurationOfStep = orçamento NFR-1 + timeout do Provedor + margem`.
- O sweeper só toca Casos com `now > stepLeaseUntil`.
- Para `Executing` vencido, o sweeper **não** vai a `ReviewRequired`. Ele entrega o comando `Reconcile` ao Execution BO, porque a consulta de Recibos pertence ao AD-5, passo 4.
- Quem perde o CAS depois de um efeito externo (o BO com Recibo na mão) não aborta. Ele entrega o comando `Reconcile` com o `executionId`.
- Os timeouts entram na tabela de Configuração com a restrição verificada na inicialização: `leaseExecução > timeoutHTTP × tentativas`.

### C-5. Gravar Evidência não é transição: o AD-2 e o AD-10 se contradizem e envenenam o `caseVersion`

- O AD-2 diz que "cada comando faz uma transição" e que "não existe evento sem transição". O AD-10 manda gravar cada Chamada de Ferramenta como Evidência **e** evento antes de retornar.
- **Agente A (Tools):** para obedecer ao AD-2, cria uma transição `Investigating → Investigating` por Evidência, incrementando o `caseVersion`.
- **Unidade B (Agent BO):** leu o `caseVersion` ao entrar em `Investigating` e, ao final, faz CAS para `DecisionProposed` com essa versão. Toda Investigação com Ferramentas falha com `STALE_VERSION`. Depois de um retry (AD-3), aborta.
- **O inverso também quebra:** se as Evidências não incrementam a versão, duas escritas concorrentes na Linha do Tempo disputam `seq`. Os escritores concorrentes são:
  - Tools dentro de `Chat()`;
  - nova Exceção chegando pelo BS;
  - negação pela UI.
- **Lacuna no spine:** nada garante a monotonicidade de `seq` sem lock, e "sem lock pessimista" (AD-3) proíbe a solução óbvia.
- **Impacto na UI (Henrique):** o polling por `caseVersion` não percebe Evidências novas se elas não incrementam a versão.

**Correção: AD-2 reescrito em duas classes de comando.**
- **Comandos de transição:** fazem CAS em `caseVersion` mais o estado e incrementam `caseVersion`.
- **Comandos de anexação:** Evidência, Exceção registrada sem mudança de estado e métrica.
  - Não fazem CAS em `caseVersion` nem o incrementam.
  - Exigem só que o estado esteja num conjunto permitido (Evidência só em `Investigating`).
  - Incrementam apenas `lastEventSeq`.
- **Alocação de `seq`:** por `$INCREMENT` num contador por Caso, dentro da mesma transação. É atômico e não conta como lock pessimista de Caso.
- **Polling da UI:** usa `lastEventSeq`, não `caseVersion`, para detectar novidade.

### C-6. De onde vem `benchmarkMode`? O Caso é criado pela Production, não pelo Bench (AD-19 × AD-9 × FR-3)

- O AD-19 diz que `benchmarkMode` é "definido na criação pelo executor do Benchmark". Pelo FR-3, porém, o Caso nasce no Interop, na primeira Exceção de um Pedido. O Bench nunca cria o Caso.
- **Unidade A (Bench, Henry):** injeta o Pedido pela Origem simulada com um campo `benchmark: {mode: "rules", runId}` no JSON.
- **Unidade B (BS, José):** copia esse campo para o Caso.
- **Resultado:**
  - qualquer Pedido externo com `"benchmark": {...}` ganha Aprovação Automática;
  - essa é exatamente a fuga que o AD-19 quer impedir;
  - o modo `rules` também pode ser escolhido por quem envia o Pedido.
- **Implementação alternativa igualmente válida:** um Agente B faz o Bench chamar a Application para "marcar" o Caso depois da criação. Abre-se uma janela em que o BP já começou a Investigação em modo `agent`, e o AD-9 diz que, depois da porta, ninguém relê o modo.

**Correção: novo AD-23 (Proveniência do Modo Benchmark).**
- O Bench cria, via Application, um `BenchmarkRun{runId, variantId, proposerMode, k, replay}` **antes** de injetar o Pedido.
- O Pedido carrega só `runId` num cabeçalho de transporte.
- Na abertura do Caso, a Application resolve `benchmarkMode`, `proposerMode` e `replay` a partir do registro `BenchmarkRun`. Pedido sem `runId` válido nunca vira Caso de Benchmark.
- Os campos são imutáveis depois da criação.
- O ponto de entrada externo de Pedidos rejeita `runId`. Só a Origem simulada, sob controle do Bench, pode enviá-lo.

---

## ALTOS

### H-1. Duas unidades donas da mesma transição: expiração, Held e Rejected

- O AD-8 permite que o sweeper faça transições. O AD-5 dá ao Execution BO a Revalidação, que verifica a validade da Aprovação (FR-20). Nenhum AD diz **quem** faz cada transição.
- **Exemplo 1, expiração (FR-18):**
  - o sweeper move `Approved → PendingApproval` aos 15 min;
  - no mesmo instante, o Execution BO revalida, também detecta a expiração e tenta `Approved → PendingApproval`;
  - o CAS salva a correção, mas um dos lados aborta e registra erro;
  - pelo AD-3, o Bench conta o abortado como falha.
- **Exemplo 2, negação:**
  - a API faz `PendingApproval → Rejected`;
  - quem faz `Rejected → Investigating`: a API, o BP ou o sweeper?
  - quem conta as negações para a regra do FR-5?

**Correção: novo AD-24.** O Core mantém uma tabela "transição → ator autorizado → comando". Cada comando da Application declara o ator, e o Core recusa a transição de ator não listado com `INVALID_ACTOR`. Proposta mínima:

| Transição | Ator | Observação |
| --- | --- | --- |
| Expiração em `Approved` | sweeper | O Execution BO só recusa a execução e entrega o comando `Expire`. |
| `Rejected → Investigating` | BP | Por comando do outbox. |
| Contador de negações | Core | Fica no agregado. |

### H-2. Nova Exceção durante `Approved` ou `Executing` (addendum §D "qualquer não terminal → Investigating" × AD-5)

- **Unidade A (BS de entrada):** segue o FR-3. A Origem reenvia o mesmo `orderId` enquanto o Execution BO está entre os passos 3 e 4. O BS registra a Exceção e transiciona `Executing → Investigating`.
- **Unidade B (Execution BO):** perde o CAS com o Recibo na mão (C-4).
- **Ambiguidade adicional:** uma Tentativa que falha **dentro** do Execution BO, em `RETRY`, é uma "nova Exceção" (vai para `Investigating`) ou uma Tentativa da Política (fica em `Executing`, depois vai para `Failed`)? Os dois caminhos são legais pela tabela.

**Correção:**
- Em `Approved`, `Authorized` e `Executing`, uma nova Exceção é um comando de anexação (C-5), sem transição. Ela é reavaliada quando a Execução terminar:
  - se o desfecho for `Resolved`, fica só registrada;
  - se o desfecho for `Failed`, vai para `Investigating`.
- Tentativas do Execution BO são `Attempt` do `Execution`, nunca `Exception` do Caso.
- A tabela §D deve ser corrigida para "qualquer não terminal, exceto Approved, Authorized e Executing".

### H-3. O contrato do Parceiro Simulado não fixa a semântica de Recibo e resposta

- O AD-16 garante que existe um OpenAPI, mas não o que ele precisa dizer para o AD-5 e o AD-14 funcionarem.
- **Henry (Sim):** devolve um Recibo em 200 com `receiptId`. Na mesma chave, devolve 409.
- **José (Execution BO):** trata 409 como Exceção e vai para Reconciliação ou para uma nova Investigação.
- **Henrique:** mostra "falha" no Caso.
- **Lacuna:** não está definido o que é "resposta incerta" (FR-23), por exemplo 502, corpo vazio ou 200 sem Recibo (FR-2).

**Correção:** o AD-13 ganha uma subseção normativa sobre o contrato do Parceiro. Ela fixa:
- a tabela de respostas e a classificação de cada uma em `success`, `business_error`, `transient` e `uncertain`;
- que `uncertain` sempre aciona a Reconciliação;
- a semântica de duplicata (C-3);
- `GET /receipts` por `idempotencyKey`, por `orderId` e por paciente;
- os campos de Recibo do AD-14.

O classificador fica no Core, como função pura sobre `{status, body}`. Assim o Modo Regras, o Execution BO e a Reconciliação usam a mesma regra.

### H-4. Chave de Equivalência canonizada em dois lugares (AD-12 × AD-13)

- O Validador confirma a P9 comparando a Chave de Equivalência do Pedido com a do Recibo "obtido do Parceiro".
- **Henry (Sim):** devolve no Recibo `examCodes` na ordem original, `collectedAt` com fuso `-03:00` e `specimenId` em minúsculas.
- **José (Core):** calcula a chave na entrada com os códigos ordenados, em UTC, preservando a caixa.
- **Resultado:** a P9 nunca confirma, e o Agente sai "pior" do que o Modo Regras, ou vice-versa.

**Correção:**
- A função `EquivalenceKey.Canonical(snapshot)` vive só no Core.
- O Simulador **não** devolve chave pronta. Ele devolve o snapshot bruto do Pedido associado ao Recibo, e o Core canoniza os dois lados.
- O contrato fixa os campos brutos obrigatórios.

### H-5. Quem emite a Aprovação Automática de Benchmark? (AD-19 × AD-5 × AD-6)

- **Henry (Bench):** faz polling do Caso até `PendingApproval` e chama `Application.Approve(author=benchmark)`.
- **José (BP):** vê `benchmarkMode = true` e aprova sozinho, porque o AD-19 só diz que o Core "aceita".
- **Resultado:**
  - há duas aprovações e uma perde no CAS;
  - o Bench "faz 1 retry, aborta e registra" (AD-3), e a variante sai como erro no relatório;
  - se o BP aprovar, a latência medida pelo Bench (NFR-2) passa a incluir o polling.

**Correção: AD-19 apertado.**
- A Aprovação Automática é emitida **só** pelo BP. Ela é um comando de transição com ator `benchmark`, disparado no mesmo passo em que o Validador exige Aprovação num Caso com `benchmarkMode = true`.
- O Bench nunca aprova. Ele só observa.
- Um CAS perdido pelo Bench numa leitura nunca conta como falha de variante.

### H-6. Estado global de Cenário no Simulador e reaproveitamento de `orderId` entre repetições (AD-13 × FR-40)

- O Bench controla "semente e variante" por HTTP, e o contrato não diz se esse controle é global ou por Pedido.
- **Henry:** implementa como estado global ("cenário ativo = P8a/v3").
- **Resultado:**
  - um segundo Caso em voo, de outra variante, de uma demo ou de k em paralelo, herda o comportamento errado do Parceiro;
  - nas k = 3 repetições, se a Origem simulada reemitir o mesmo `orderId`, a repetição 2 encontra o Caso terminal da 1, ou o Recibo dela pela Chave de Equivalência. A P9 "acerta" por contaminação.

**Correção:**
- O Cenário é endereçado por Pedido: `POST /sim/api/v1/scenarios` devolve um `scenarioInstanceId`, e a Origem simulada emite Pedidos já vinculados a ele.
- O Parceiro, a saúde e os logs respondem conforme o `scenarioInstanceId` do Pedido consultado.
- `orderId`, `patientId` e `specimenId` são gerados pelo Simulador com namespace por `runId` e repetição.
- A regra "o `orderId` vem do Pedido e nunca é gerado" continua valendo do lado do Signal Noir.

### H-7. Transação aberta atravessando I/O (AD-2 × AD-10 × AD-11)

- O AD-2 exige transição e evento na mesma transação, mas não diz o que **não** pode estar dentro dela.
- **Agente A (Agent BO):** abre `TSTART`, chama `Chat()` (de 20 a 60 s, com Tools que gravam Evidências e fazem HTTP ao Simulador) e faz `TCOMMIT` com a Proposta.
- **Efeitos:**
  - as Evidências ficam invisíveis para a UI durante a Investigação;
  - um rollback por timeout apaga Evidências, o que viola o FR-6 (Evidência nunca é apagada) e o FR-11 (as Evidências coletadas até ali precisam aparecer);
  - os locks de linha do IRIS ficam presos por dezenas de segundos.
- **Agente B (Execution BO):** faz o mesmo em volta do POST ao Parceiro.

**Correção: regra adicionada ao AD-2.** Toda transação da Application é curta e não contém I/O (HTTP, LLM, envio a BS). Cada Evidência é commitada individualmente (C-5). A sequência "ler, chamar fora, gravar" é sempre "CAS de entrada, I/O fora de transação, CAS de saída".

---

## MÉDIOS

### M-1. Identidade de Proposta: id novo ou versão nova?

- O AD-3 cita `proposalVersion` e o FR-17 exige aprovar a "versão exata", mas não está definido se a reinvestigação depois de `Rejected` ou de `Held` cria um novo `prop_…` ou incrementa a versão do mesmo.
- **Henrique:** a UI envia `{proposalId}`.
- **José:** a API espera `{proposalVersion}` inteiro por Caso.
- **Correção:**
  - Toda nova Proposta tem um novo `proposalId` e `proposalVersion` monotônico por Caso.
  - O comando de Aprovação é `{caseId, caseVersion, proposalId, proposalVersion, decision, actor}` e entra no OpenAPI.

### M-2. Aprovação repetida: 409 ou sucesso idempotente? (FR-19 × AD-3)

- Pelo AD-3, o segundo clique, ou um POST reenviado depois de timeout de rede, recebe 409 `STALE_VERSION`, e a UI mostra erro mesmo quando a Aprovação valeu.
- **Correção:**
  - Uma Aprovação com a mesma `(proposalId, proposalVersion, decision)` já registrada devolve 200 com o `approvalId` existente e `idempotentReplay: true`.
  - Só uma decisão diferente, ou uma versão vencida, devolve 409.
  - A regra fica no Core.

### M-3. O Validador é puro, mas precisa de um Recibo "obtido do Parceiro" (AD-1 × AD-12)

- **Agente A:** o Validador recebe a Evidência de Recibo que o Agente citou, possivelmente de 15 s antes.
- **Agente B:** a Application faz uma consulta nova via Tools antes de chamar o Validador.
- **Resultado:** os desfechos divergem quando o Recibo é revertido no Cenário.
- **Correção:**
  - A Application sempre faz uma consulta de confirmação pela porta de Ferramentas. Ela fica registrada como Evidência com `purpose: confirmation`.
  - A consulta passa ao Validador o Recibo com `observedAt`.
  - O Validador recusa Evidência de Recibo citada só pelo propositor.

### M-4. Implementação `rules` mora em `Bench`, mas é chamada pela Investigação no Interop

- A árvore coloca o Modo Regras em `Bench/`. A porta de proposição é invocada pelo Interop (AD-9), o que cria a dependência Interop → Bench, fora do grafo permitido.
- **Correção:**
  - A interface da porta fica em `SignalNoir.Application`.
  - As implementações ficam em `SignalNoir.Proposers.Rules` e `SignalNoir.Proposers.Agent`, ou o `Agent` fica no Interop.
  - O Bench só escolhe o modo pelo `BenchmarkRun` (C-6).

### M-5. Resolução pelo Operador: um passo ou dois? (FR-29 × FR-16)

- **Henrique:** a UI tem um botão "Resolver com RETRY" que espera a Execução.
- **José:** o Core cria a Proposta do operador, vai para `DecisionProposed` e depois para `PendingApproval`, o que exige uma segunda Aprovação do mesmo Operador.
- **Correção:** o AD-12 declara se a Proposta de autor `operator:<nome>` gera uma Aprovação implícita do mesmo autor, registrada como `Approval{by: operator, implicit: true}`, ou se exige um segundo passo. O OpenAPI expõe uma única forma.

### M-6. Caminho do Replay (AD-19 × FR-41)

- Não está definido se um Caso `replay = true` passa pela Production e pelo Execution BO.
- Se um Agente B reproduzir pela Production, ele chama o Parceiro de verdade. Se não passar pela Production, o "Caso" de Replay não tem Visual Trace nem Linha do Tempo real.
- **Correção:** o Replay é só do Bench e só de relatório.
  - Ele reproduz Propostas gravadas na porta de proposição, como um terceiro propositor `replay` que devolve o DTO gravado.
  - O resto do fluxo é real, contra o Simulador.
  - O Caso é marcado `replay = true` via `BenchmarkRun`.

### M-7. Divergência de Recibo em Caso terminal (AD-14)

- "Prevalece o Parceiro e o Caso é atualizado por comando", mas o Caso já está `Resolved` e o estado é terminal.
- **Agente A:** inventa `Resolved → Resolved`.
- **Agente B:** reabre o Caso para `ReviewRequired`.
- **Correção:**
  - A atualização da cópia de Recibo é um comando de anexação (`receipt_corrected`) permitido em terminais.
  - Ela nunca muda o estado.
  - Se o Recibo canônico deixar de existir, o comando gera um evento `receipt_missing` e alerta.

---

## BAIXOS

### L-1. 409 com códigos diferentes, retry igual

- O AD-3 manda o Bench fazer 1 retry em "conflito", e `INVALID_TRANSITION` também é 409.
- **Correção:** só `STALE_VERSION` é passível de retry. `INVALID_TRANSITION` e `INVALID_ACTOR` nunca são.

### L-2. `actor` dos eventos de Ferramenta

- A Ferramenta chamada pelo propositor `rules` vira `rules` ou `system`? E o pacote base?
- **Correção:**
  - O pacote base tem `actor: system`.
  - As chamadas adicionais têm `actor` igual ao propositor.
  - `payload.tool` é obrigatório.

### L-3. Cursor da lista de Casos

- O AD-17 não diz sobre o que é o cursor. Se for `updatedAt` e as anexações não atualizarem `updatedAt`, a lista perde mudanças.
- **Correção:** o cursor é feito sobre `(lastEventAt, caseId)`, e toda anexação atualiza `lastEventAt`.

### L-4. Vocabulário fechado de comandos

- O AD-6 define o comando como `(caseId, caseVersion, tipo)`, mas não enumera os tipos.
- **Correção:** o enum vive no Core e é usado pelo outbox (C-1). Os tipos são `Investigate`, `Execute`, `Reconcile`, `Expire`, `Reassess` e `Resume`.

---

## Resumo das mudanças propostas no spine

| Tipo | Item | Fecha |
| --- | --- | --- |
| Novo | AD-20 Outbox de comandos | C-1, L-4 |
| Apertado | AD-5: o passo 1 é um CAS que cria `Execution` e o estado `Authorized` ou `Executing` | C-2 |
| Novo | AD-21 Chave de Idempotência, com a semântica do Parceiro | C-3, H-3 |
| Novo | AD-22 Lease de etapa e ordem de timeouts | C-4 |
| Reescrito | AD-2: comandos de transição e de anexação, `seq` por `$INCREMENT`, transação sem I/O | C-5, H-7, M-7 |
| Novo | AD-23 Proveniência por `BenchmarkRun` | C-6, M-6 |
| Novo | AD-24 Tabela transição → ator | H-1, H-2 |
| Apertado | AD-19: Aprovação Automática emitida só pelo BP | H-5 |
| Apertado | AD-13: contrato normativo do Parceiro, Cenário por instância, namespace de IDs | H-3, H-6 |
| Apertado | AD-12: canonização da Chave de Equivalência e consulta de confirmação | H-4, M-3 |

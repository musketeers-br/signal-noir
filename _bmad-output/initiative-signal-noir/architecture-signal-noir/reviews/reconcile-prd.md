# Reconciliação de entrada: PRD → Architecture Spine (Signal Noir)

- **Data:** 2026-10-19
- **Entradas:** `prd-signal-noir/prd-signal-noir.md`, `prd-signal-noir/addendum.md`, `architecture-signal-noir/architecture-signal-noir.md`, `architecture-signal-noir/.memlog.md`
- **Método:** cada FR, NFR e restrição do PRD (§5, §6, §7, §8, §9) foi procurado no spine como AD, convenção, seed ou item Deferred explícito. Também foram procuradas regras do spine que contradizem o PRD.
- **Escala de severidade:** **Alta** bloqueia a implementação ou gera comportamento contrário ao PRD. **Média** deixa uma decisão estrutural para cada frente inventar. **Baixa** é ajuste de redação ou de rastreabilidade.

## Resumo

| # | Achado | Tipo | Severidade |
|---|---|---|---|
| 1 | AD-2 proíbe "evento sem transição", mas o FR-7 exige eventos que não são transições | Contradição | Alta |
| 2 | Nenhum registro de Pedido fora do Caso: não há onde guardar a Chave de Equivalência, garantir um Caso aberto por `orderId` ou atender P9 | Lacuna | Alta |
| 3 | Políticas, Catálogo de Mapeamentos e pré-condições não têm dono, versionamento nem vocabulário verificável | Lacuna | Alta |
| 4 | A Chave de Idempotência não tem regra de derivação, e a Reconciliação só roda "após timeout" | Lacuna / contradição parcial | Alta |
| 5 | NFRs ausentes do `binds` e do mapa; NFR-10, NFR-11 e NFR-5 em risco com o seed atual | Lacuna | Alta |
| 6 | O Simulador não tem isolamento de Cenário por Caso; o P3 não tem gatilho determinístico | Lacuna | Média |
| 7 | O Replay não tem porta: AD-9 só admite `rules` ou `agent` | Lacuna / contradição | Média |
| 8 | O orçamento de 20 s não cobre o tempo do LLM, e não está claro se o pacote base consome as 6 chamadas | Lacuna | Média |
| 9 | Validade da Aprovação e invalidação da autorização depois de uma Revalidação reprovada | Lacuna | Média |
| 10 | AD-6 cria uma sessão de Production por comando, o que fragmenta o Visual Trace (FR-37) | Contradição parcial | Média |
| 11 | Retomada após reinício: falta a regra por estado e falta o volume durável | Lacuna | Média |
| 12 | Nova Exceção durante `Executing` ou `PendingApproval` (regra "qualquer não terminal → Investigating") | Ambiguidade herdada | Média |
| 13 | Artefatos do Benchmark sem lugar: Gabarito, ajuste/teste, export (FR-8), relatório, comandos | Lacuna | Média |
| 14 | A Stack fixa IRIS Community e IPM `latest`, mas Q-5 está aberta e o PRD pede reprodutibilidade | Contradição | Baixa |
| 15 | Chave ausente no arranque, custo estimado, `suspicious`, Aprovação repetida retornando 409 e Aprovação de Proposta do Operador | Lacunas pequenas | Baixa |

---

## Achados detalhados

### 1. AD-2 contradiz o FR-7 (eventos que não são transições) — **Alta**
- **PRD:** FR-7 (§4.2), FR-6 ("Evidência obsoleta é marcada por um novo evento") e FR-10 ("Cada Chamada de Ferramenta vira uma Evidência").
- **Spine:** a regra do AD-2 diz "Não existe transição sem evento **nem evento sem transição**". O AD-10 grava cada Chamada de Ferramenta como evento da Linha do Tempo, e o AD-3 manda o sweeper "registrar que pulou".
- **Problema:** o FR-7 lista eventos que não mudam o estado do Caso, como Chamada de Ferramenta, decisão do Validador, Revalidação aprovada, Reconciliação sem Recibo e Evidência obsoleta. Lido ao pé da letra, o AD-2 proíbe esses eventos ou obriga a criar pseudo-estados. Também falta dizer se o evento de Ferramenta incrementa `caseVersion`. Se incrementar, cada Ferramenta invalida a tela de Aprovação aberta (AD-3).
- **Correção sugerida:** reescrever o AD-2 assim: "toda transição grava evento na mesma transação; eventos sem transição (Evidência, Validador, Revalidação, Reconciliação) também só entram por comando da Application". Definir se eventos sem transição incrementam `caseVersion` ou só `lastEventSeq`. Sugestão: só `lastEventSeq`, com o CAS de Aprovação sobre `proposalVersion`.

### 2. Pedido sem registro próprio — **Alta**
- **PRD:** FR-1 (correlação de todo Pedido aceito), FR-3 ("no máximo um Caso aberto por `orderId`"), FR-10 ("Recibos e Pedidos recentes, com busca por paciente sintético"), FR-47, FR-24, P9 (addendum §E) e addendum §C (Chave de Equivalência "calculada na entrada").
- **Spine:** o ERD tem `CASE`, `EXCEPTION`, `EVIDENCE` e outros, mas nenhuma entidade `ORDER`. O AD-12 diz que o Validador confirma a Chave de Equivalência "com um Recibo obtido do Parceiro", mas o Recibo só tem `orderId`, `idempotencyKey` e `receiptId`, sem os campos da chave.
- **Problema:**
  - Pedidos entregues com sucesso não geram Caso, e o P9 depende justamente de um Pedido anterior bem-sucedido.
  - Não está definido de onde vem o snapshot do Pedido anterior: da Production ou da API do Parceiro Simulado.
  - A unicidade de Caso aberto por `orderId` não tem mecanismo. O CAS do AD-3 cobre atualização, não criação concorrente.
- **Correção sugerida:**
  - Adicionar ao seed uma entidade `Order`/`OrderSnapshot` da Production, gravada no FR-1, com `equivalenceKey` indexada e `transactionIds[]`.
  - Criar um AD com a regra "Caso aberto único por `orderId`", aplicada por índice único condicional ou por um campo `openCaseId` no `Order` com CAS.
  - Fixar no AD-12 a fonte dos campos de equivalência do candidato. Sugestão: o Recibo do Parceiro mais o `OrderSnapshot` local, ou um endpoint do Simulador que devolva o Pedido recebido, definido no OpenAPI.

### 3. Políticas, Catálogo de Mapeamentos e pré-condições sem dono — **Alta**
- **PRD:** Glossário §3 ("Política — regra de negócio versionada, consultável pelo Agente e aplicada pelo Validador"; "Catálogo de Mapeamentos — conjunto versionado"), FR-10, FR-12 (pré-condições), FR-14, FR-15, FR-18 ("Evidência que contradiga alguma pré-condição"), FR-20 ("vigência da Política") e FR-9 (versão da Política registrada).
- **Spine:** não diz onde vivem Políticas e Mapeamentos (Core? configuração? Simulador?), como são versionados, nem como a Revalidação verifica pré-condições declaradas pelo Agente. O addendum dá o formato `preconditions[{check, expected}]`, mas não há vocabulário fechado de `check`.
- **Problema:**
  - Se o Agente escrever pré-condições em texto livre, a Revalidação deixa de ser determinística, ou o código ignora as pré-condições e só usa as fixas.
  - "Vigência da Política" exige saber qual versão a Proposta usou e qual é a atual.
  - A "Política de tentativas" que leva a `Executing → Failed` não tem dono.
- **Correção sugerida:** criar um AD do tipo "Políticas e Catálogo de Mapeamentos são dados versionados do produto em `SignalNoir.Core`/Application (não do Simulador), lidos pela porta de Ferramentas e pelo Validador; cada Proposta grava `policyVersion` e `mappingCatalogVersion`". Acrescentar um catálogo fechado de pré-condições verificáveis (por exemplo `PARTNER_ERROR_RATE_BELOW`, `ORDER_ACTIVE_AT_SOURCE`, `NO_MAINTENANCE_WINDOW`, `POLICY_VERSION_EQUALS`). O Validador rejeita checks fora do catálogo, e a Revalidação e o FR-18 avaliam os mesmos checks.

### 4. Chave de Idempotência e Reconciliação — **Alta**
- **PRD:** Glossário ("identificador estável por Pedido e Ação autorizada"), FR-22 e FR-23 ("Depois de timeout ou resposta incerta, o sistema consulta Recibos **antes de qualquer novo envio**"), NFR-6 e SM-4.
- **Spine:** o AD-1 coloca "regras de idempotência" no Core sem dizer quais. A etapa 4 do AD-5 só cobre "Reconciliação por Recibo após timeout".
- **Problema:**
  - Sem a fórmula da chave, cada frente inventa a sua.
  - Pelo glossário, uma chave "por Pedido e Ação" muda quando a Ação muda. Exemplo: um `RETRY` com resposta perdida, seguido de `APPLY_APPROVED_MAPPING`, sai com outra chave e duplica a entrega se a Reconciliação procurar só pela chave.
  - Também falta dizer se retries internos da Política reutilizam a mesma chave. Pela regra, deveriam.
- **Correção sugerida:** acrescentar ao AD-5 ou criar um AD de idempotência com três pontos:
  - a fórmula determinística da chave, por exemplo `hash(orderId, action, mappingId?)` estável entre retries, reinício e Aprovações repetidas;
  - a regra "antes de **todo** envio, se houve envio anterior incerto para o mesmo `orderId` ou a mesma Chave de Equivalência, consultar Recibos por `orderId` e não só por `idempotencyKey`";
  - o contrato no OpenAPI do Simulador que exige que o Parceiro deduplique por `idempotencyKey`.

### 5. NFRs sem lugar no spine (instalação, plataformas, durabilidade) — **Alta**
- **PRD:** §5 NFR-1 a NFR-11, em especial NFR-10 (≤ 15 min até o primeiro Caso), NFR-11 (x64 e ARM64) e NFR-5; FR-42; FR-4 ("reiniciar o container"); §6 Custo.
- **Spine:** o `binds` lista só FRs. O Capability Map não tem linhas de NFR. Só NFR-1 (AD-10) e NFR-9 (AD-15 e Deferred) são citados.
- **Problema:**
  - **NFR-10:** o seed faz um build multi-stage com Node 24 compilando a SPA e instala o IPM na máquina do jurado. Isso depende de Docker Hub e npm, aumenta o tempo de `docker compose up` e é o ponto mais provável de falha da instalação.
  - **NFR-11:** a imagem `node:24` e o IPM precisam funcionar nas duas arquiteturas, e o retag de cada arquivo `.tar` precisa cair na mesma tag do compose. Nada disso está escrito.
  - **NFR-5 e FR-4:** o seed não declara volume durável (Durable `%SYS` ou volume de dados). Um `docker compose down/up` apaga Casos e Aprovações pendentes.
  - **NFR-2 a NFR-4, NFR-6 e NFR-7** não apontam para nenhum AD ou convenção de medição.
- **Correção sugerida:**
  - Acrescentar linhas de NFR ao Capability Map.
  - Decidir no seed que a SPA é compilada no CI ou pelo time e o estático é commitado ou anexado, para que o jurado não precise de Node. Fixar a versão do IPM, ou embutir o instalador, e medir o build nas duas arquiteturas.
  - Declarar um volume nomeado ou Durable `%SYS` no compose.
  - Fixar a tag única de retag por arquitetura no README.

### 6. Simulador: isolamento por Caso e determinismo do P3 — **Média**
- **PRD:** FR-32 ("A mesma semente produz a mesma sequência de respostas"), FR-39 (um comando roda tudo), FR-40 (k = 3), FR-20 e P3 (o mundo muda **entre** Aprovação e Execução) e NFR-2 (p50/p95 exigem várias execuções).
- **Spine:** o AD-13 menciona "controle de semente e variante feito pelo Benchmark" por HTTP, como se fosse um estado global do Simulador.
- **Problema:** com um Cenário ativo global, os Casos do Benchmark precisam rodar em série, ou um Caso contamina outro. O P3 exige que o Simulador mude de estado depois da Aprovação Automática e antes da Revalidação, uma janela de menos de 5 s. Sem um gatilho definido, o resultado vira condição de corrida e não é reproduzível.
- **Correção sugerida:** determinar que o Cenário e a variante se ligam a cada Pedido, por exemplo por `partnerId` ou por um cabeçalho `X-Scenario` derivado do `orderId`, e que a sequência de respostas é função da semente e do contador de requisições daquele Pedido. Para o P3, definir no contrato um gatilho determinístico, como "a N-ésima consulta de saúde após a Aprovação devolve degradado". Alternativa: o executor do Benchmark muda o estado do Simulador por HTTP antes de liberar a Aprovação. Declarar se o Benchmark roda em série ou em paralelo.

### 7. Replay sem porta — **Média**
- **PRD:** FR-41, FR-49 (validação rápida com "resultado gravado"), FR-38, FR-45, §6, UJ-6 e Glossário ("reexecução de um Caso a partir de respostas gravadas do Agente").
- **Spine:** o AD-19 só diz que Casos de Replay têm `replay = true` e ficam fora das métricas. O AD-9 admite apenas os modos `rules` e `agent`, e "fora do Benchmark, o modo é `agent`".
- **Problema:** não há mecanismo para gravar respostas do Agente nem para reproduzi-las. A ambiguidade do PRD sobre se a validação rápida roda com o Agente ao vivo ou por Replay também não foi resolvida. Um "replay" implementado por fora do AD-9 seria um terceiro caminho, contra o próprio AD-9.
- **Correção sugerida:** acrescentar ao AD-9 uma terceira implementação da porta de proposição, `replay`, que lê a saída gravada do Agente (por Caso de referência e hash da Evidência) e marca `replay = true`. Ou declarar no Deferred que o Replay só existe como gravação de vídeo. Fixar que o FR-49 roda ao vivo e compara com o resultado gravado da Execução de Referência, que fica versionado em `bench/reference/`.

### 8. Orçamento da Investigação — **Média**
- **PRD:** NFR-1 (≤ 6 chamadas e ≤ 20 s), FR-11, FR-53 ("o orçamento do NFR-1 passa a valer para a coleta"), NFR-8 e P9 (busca em vários passos).
- **Spine:** no AD-10, `SignalNoir.Tools` aplica o orçamento "por contagem e por tempo" e cada chamada passa por ele, inclusive as do pacote base.
- **Problema:**
  - O tempo de 20 s inclui o tempo de LLM do `Chat()` síncrono, que não passa pela porta de Ferramentas. Ninguém corta um `Chat()` que demora 40 s, e o NFR-8 ("sem derrubar a Production") depende disso. O timeout do BO precisa estar definido.
  - Se o pacote base consome as 6 chamadas, o Agente pode ficar sem orçamento para o follow-up do P9, e o Modo Regras e o Agente teriam orçamentos efetivos diferentes, o que importa para a honestidade do Benchmark.
- **Correção sugerida:** acrescentar ao AD-10 ou ao AD-11:
  - o deadline da Investigação como relógio de parede, aplicado pelo Agent BO (timeout do `Chat()`/BO) e não só pelas Ferramentas;
  - se o pacote base conta no orçamento, e qual é o número;
  - que o mesmo orçamento vale para `rules` e `agent`.

### 9. Validade da Aprovação e autorização revogada — **Média**
- **PRD:** FR-18 (expira em 15 min ou por Evidência contraditória), FR-20 ("validade da Aprovação" como pré-condição), FR-21, FR-36 ("prazo de validade" na tela) e addendum §D (`Approved → PendingApproval`).
- **Spine:** o AD-5 ordena "1. registro durável da autorização; 2. Revalidação". O AD-8 menciona varrer Casos "vencidos". Nenhum AD define onde `expiresAt` é calculado nem quem detecta Evidência contraditória.
- **Problema:** se a Revalidação falha depois da autorização registrada, o que acontece com a autorização gravada? Falta dizer se ela é anulada no mesmo comando que leva a `Held` ou `Cancelled`. Também não está dito se a expiração é verificada sob demanda (na Revalidação) ou pelo sweeper, nem como fica a exibição do prazo.
- **Correção sugerida:** acrescentar ao AD-5:
  - `expiresAt` é gravado na Aprovação pelo Core;
  - a validade é verificada na Revalidação (fonte de verdade) e o sweeper apenas reflete a expiração na interface;
  - a autorização registrada é consumida ou anulada no mesmo comando da transição de saída;
  - Evidência nova que contradiz um check de pré-condição (achado 3) leva `Approved → PendingApproval` via Application.

### 10. Visual Trace fragmentado pelo AD-6 — **Média**
- **PRD:** FR-37 ("O link leva às mensagens do Pedido"), FR-9 e NFR-9 ("Toda chamada ao Agente é rastreável no Visual Trace") e UJ-1 ("um link para o Visual Trace").
- **Spine:** pelo AD-6, cada comando de REST, Benchmark ou sweeper entra por um Business Service, o que gera uma nova sessão da Production por comando. O AD-15 lista o que precisa aparecer no Visual Trace, mas não como juntar as sessões.
- **Problema:** um Caso terá várias sessões (entrada, Investigação, Aprovação, Reavaliação, Execução). Um link único só mostra parte do fluxo.
- **Correção sugerida:** acrescentar ao AD-15 que o Caso guarda `productionSessionIds[]`, gravado a cada comando, e que o FR-37 mostra a lista ou a sessão mais relevante. Alternativa: reaproveitar o `SessionId` original quando o comando é roteado ao BP, se o build 154 permitir.

### 11. Retomada após reinício por estado — **Média**
- **PRD:** FR-4 (Investigating → `ReviewRequired` "investigação interrompida"; `PendingApproval` e `Held` reaparecem), FR-19, P3/idempotência ("reinício durante Executing") e NFR-5.
- **Spine:** o AD-8 varre "Casos órfãos ou vencidos em estados intermediários" e "reconcilia". Mas o AD-5 coloca a Reconciliação só no Execution BO, e o AD-8 proíbe efeitos ao sweeper.
- **Problema:** falta a tabela "estado ao reiniciar → ação". Em `Executing`, falta dizer que o sweeper manda o comando de Reconciliação ao Execution BO e não reenvia. Em `Approved`, falta dizer se a Revalidação é refeita. A leitura do AD-4 e do AD-8 deixa isso aberto.
- **Correção sugerida:** acrescentar ao AD-8 uma tabela curta:
  - `Investigating` → `ReviewRequired`;
  - `Executing` → comando `Reconcile` ao Execution BO, que consulta Recibos antes de qualquer reenvio;
  - `Approved` → Revalidação refeita;
  - `PendingApproval`, `Held` e `ReviewRequired` → mantidos.
  Acrescentar também a regra de detecção de órfão, por exemplo "sem sessão de Production ativa e `updatedAt` mais antigo que X".

### 12. Nova Exceção em estados intermediários — **Média** (ambiguidade herdada do PRD)
- **PRD:** FR-3 ("ele volta a `Investigating`") e addendum §D ("qualquer não terminal → Investigating"; `Executing → Failed` por tentativas esgotadas).
- **Spine:** não trata o caso.
- **Problema:** uma Tentativa da própria Execução que falha também é uma Exceção. Pela tabela, ela levaria `Executing → Investigating`, o que conflita com `Executing → Failed` e com a Política de tentativas. Em `PendingApproval` ou `Approved`, a nova Exceção precisa invalidar a Proposta e a Aprovação vigentes. O AD-7 só cobre `Held`.
- **Correção sugerida:** em um AD de ciclo de vida, distinguir Exceção de Tentativa da Execução em curso (tratada pela Política de tentativas dentro do Execution BO) de Exceção nova vinda do workflow. Nova Exceção em `PendingApproval` ou `Approved` torna a Proposta não vigente e anula a Aprovação, pela mesma regra do AD-7. Levar a ambiguidade ao PRD (FR-3 e §D).

### 13. Artefatos do Benchmark sem lugar — **Média**
- **PRD:** FR-8 (export suficiente para recalcular métricas sem a Production), FR-32 (separação entre ajuste e teste, "prompts e regras não são ajustados com variantes de teste"), FR-33 (Gabarito declarado antes), FR-39 (relatório em duas partes), FR-40 (faixas sobre k = 3; aviso de modelo diferente), FR-48 (regras versionadas junto com o Gabarito), FR-49 e SM-C2/SM-C4.
- **Spine:** o `SignalNoir.Bench` e o AD-19 cobrem a execução, mas não dizem onde ficam Gabarito, variantes, partições, export, relatório e Execução de Referência gravada. Também não dizem qual é o ponto de entrada dos comandos de "um comando" (`docker compose exec … iris session …`, script, endpoint).
- **Problema:**
  - Cada frente pode guardar o Gabarito em lugar diferente.
  - A separação entre ajuste e teste fica sem barreira estrutural. Exemplo: o executor aceita rodar o conjunto de teste sem marcar.
  - O formato do export (FR-8) é o contrato entre IRIS e o relatório, e está ausente.
- **Correção sugerida:** acrescentar à árvore do seed `bench/scenarios/<família>/{tuning,test}/`, `bench/gabarito/`, `bench/rules/` e `bench/reference/<provedor-modelo>/`. Acrescentar uma convenção para o JSON de export por Caso (versionado e com `synthetic`/`replay`) e um AD curto: "o relatório é calculado só a partir dos exports, e o conjunto de teste é marcado e só entra nas metas".

### 14. Stack fixa decisões ainda abertas — **Baixa**
- **PRD:** Q-5 (IRIS ou IRIS for Health, aberta), FR-43 ("IRIS ou IRIS for Health, conforme Q-5"), FR-42 e NFR-10 (reprodutibilidade).
- **Spine:** a Stack diz "InterSystems IRIS Community com AI Hub" e "IPM (ZPM) | latest", ao mesmo tempo em que o Deferred mantém a Q-E aberta.
- **Correção sugerida:** marcar a linha da imagem como `[ASSUMPTION até Q-E]` e fixar a versão do IPM. Uma versão `latest` instalada na máquina do jurado contraria a instalação reproduzível.

### 15. Lacunas pequenas — **Baixa**
- **FR-44 e NFR-8, chave ausente:** o AD-18 descreve a materialização da chave no arranque, mas não diz que, sem chave ou com chave inválida, esse passo **não pode abortar** a inicialização. Acrescentar: "falha de configuração do Provedor é registrada e os Casos vão para `ReviewRequired` com o motivo 'Provedor indisponível'".
- **FR-35, NFR-4 e NFR-9, custo estimado:** não há lugar para a tabela de preço por modelo nem para a fórmula de `estCostUsd`. Sugestão: tabela versionada em configuração, com o custo marcado como estimado.
- **FR-13, conteúdo suspeito:** o AD-10 diz "trechos suspeitos são marcados", mas não diz quem marca (detector determinístico na porta de Ferramentas ou o Agente). Para não depender do LLM, o detector deve ser determinístico.
- **FR-19 e UJ-1, Aprovação repetida:** com o AD-3, o segundo clique recebe HTTP 409 `STALE_VERSION`. Isso atende ao FR-19, mas a experiência fica melhor se a repetição da **mesma** Aprovação, pelo mesmo autor e na mesma versão, devolver o resultado da primeira de forma idempotente. Decidir no contrato da API.
- **FR-29 e FR-16, Proposta do Operador:** não está definido se a Ação escolhida pelo Operador no Dossiê ainda exige Aprovação separada, ou se a escolha já vale como Aprovação. Fixar no Validador (AD-12).
- **FR-16, Política de Aprovação:** a regra "`RETRY` e `APPLY_APPROVED_MAPPING` exigem Aprovação; `HOLD` não" não aparece no spine. Citá-la no AD-12 como saída `requiresApproval` do Validador.
- **§6, "Catálogo compilado":** o AD-12 fala em Validador, mas não diz que o Catálogo de Ações é uma estrutura compilada (classe ou enum) e não um dado editável. Acrescentar uma linha.
- **Addendum §A, REST + SSE:** o AD-17 adia o SSE. Isso não contradiz nenhum FR (o FR-34 só pede atualização sem recarregar), mas vale registrar no PRD ou no addendum que o polling substitui o SSE.

---

## Cobertura conferida sem achado

| Item | Onde está no spine |
|---|---|
| A IA propõe e a aplicação governa; o Agente não escreve | AD-5, AD-11, AD-12 |
| Ferramentas somente leitura, fechadas e registradas como Evidência | AD-10 |
| Modo Regras com as mesmas Ferramentas, cego à origem | AD-9, AD-10 |
| Aprovação Automática só no Modo Benchmark | AD-19 |
| Aprovação de versão exata e concorrência (Q-7) | AD-3 |
| Divergência entre Production e Caso (Q-8) | AD-4 |
| Reavaliação nunca reaproveita Aprovação | AD-7, AD-8 |
| Recibo canônico | AD-14 |
| Plano B, Evidência Pré-coletada (FR-53) | AD-9, AD-10, Q-B |
| Segredos fora de Caso, log, export e repositório | AD-18, convenção de Logs |
| Rótulos `synthetic` e `replay` | Convenção "Rótulos" (o mecanismo de Replay continua no achado 7) |
| Sem registry público; build 154 por `docker load` e retag | Stack, Structural Seed |
| Itens fora do escopo (Incidentes, P2, Fases, autenticação, System 1, HL7/FHIR) | Deferred |
| Provedor configurável (FR-50) | AD-18 |

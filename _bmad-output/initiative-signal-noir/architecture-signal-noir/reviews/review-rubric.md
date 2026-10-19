# Revisão por rubrica — Architecture Spine Signal Noir

- **Alvo:** `architecture-signal-noir.md` (status `draft`, 2026-10-19), com `.memlog.md`, `research-stack.md` e `../prd-signal-noir/prd-signal-noir.md` (+ `addendum.md` §D).
- **Brownfield conferido:** `Dockerfile`, `docker-compose.yml`, `module.xml`, `iris.script`, `merge.cpf`, `.iris_init`, `src/dc/sample`, `tests/dc/sample/unittests`, `.github/workflows/*`.
- **Data da revisão:** 2026-10-19. Nenhum arquivo foi alterado.

## Veredito

O núcleo de domínio é forte: AD-1 a AD-19 fecham bem estado, concorrência, caminho único de Execução e Validador. O envelope operacional e a ratificação do brownfield estão fracos, e há um achado crítico: o repositório ainda publica imagem em registry público a cada push. **O spine não está pronto para servir de substrato sem correções.**

**Contagem:** 1 crítico · 6 altos · 10 médios · 8 baixos.

## Notas por item da rubrica

| # | Item da rubrica | Nota | Achados |
| --- | --- | --- | --- |
| 1 | Fixa os pontos reais de divergência do nível abaixo, sem omitir nenhum | **adequate** | H3, H4, H6, M2, M4, M7, M8 |
| 2 | A Rule de cada AD é aplicável e de fato impede a divergência declarada | **adequate** | H3, M1, M3, M10 |
| 3 | Nada em Deferred permite que duas unidades divirjam | **thin** | H5, M6, L3 |
| 4 | A tecnologia citada está verificada e atual | **adequate** | M9, L1, L7 |
| 5 | Ratifica o codebase brownfield, sem contradizê-lo | **broken** | C1, H2, M9, L2 |
| 6 | Cobre os requisitos do PRD que o originou | **adequate** | M4, M5, M7, M8, L8 |
| 7 | Toda dimensão da altitude (initiative) está decidida, adiada ou em aberto, inclusive o envelope operacional | **thin** | C1, H1, H2, M6, M10, L6 |

### Comentário por item

1. **Pontos de divergência — adequate.** A cobertura dos autores de mutação é exemplar: API, Interop, Bench e Tasks passam por Application, com CAS e um BS de comandos. Mas ficam abertos pontos em que duas frentes vão decidir de formas diferentes:
   - a semântica de retry do Execution BO (H3);
   - onde mora o Modo Regras (H4);
   - o isolamento do Gabarito (H6);
   - a proteção contra resultado tardio de uma Investigação (M2);
   - Replay e validação rápida (M4);
   - a correlação com o Visual Trace (M7);
   - a Aprovação na resolução do Operador (M8).
2. **Rules aplicáveis — adequate.** A maioria das regras é verificável em code review. Exceções:
   - AD-2 é autocontraditório (M3);
   - AD-8 proíbe timers que o fluxo exige (H3);
   - AD-10 promete um orçamento de tempo que a porta de Ferramentas não tem como impor (M1);
   - AD-18 não diz *quando* acontece a "inicialização" (H1).
3. **Deferred — thin.** Adiar o formato dos DTOs abre divergência justamente entre o Modo Regras e o Agente, que FR-48 manda serem escritos por pessoas diferentes (H5). "Autenticação fora" não decide a configuração de segurança das web apps (M6).
4. **Tecnologia — adequate.** As versões do front-end foram checadas no npm em 19/10, e o build 154, `VERSIONPROPERTY` e `%SYS.Task.Definition` têm fonte. Ficam abertos:
   - o IPM "latest" sem pin;
   - a tag de retag, que não foi fixada;
   - o TypeScript 6, peer do SvelteKit 3, ausente da tabela;
   - o comportamento de `ServeFiles` com a web app do IRIS 2026, não confirmado.
5. **Brownfield — broken.** O spine afirma "não há registry público", mas o repositório tem workflows que publicam no ghcr.io e fazem deploy no Cloud Run a cada push em `master` (C1). O bind mount do compose esconderia o estático copiado pelo build multi-stage (H2). Módulo `dc-sample`, namespace `IRISAPP` e `SystemMode` não foram ratificados nem renomeados (L2).
6. **Cobertura do PRD — adequate.** `binds` cobre FR-1 a FR-53 sem FR-25 a FR-27, que estão corretamente fora. Ficam sem casa arquitetural:
   - FR-41 e FR-49 (M4);
   - FR-37 e a correlação de FR-1 (M7);
   - a Aprovação em FR-29 (M8);
   - FR-18 (L8).
   
   O status de FR-53 diverge do PRD §9 (M5).
7. **Altitude e envelope operacional — thin.** Ambiente único local e Provedor via `.env` estão decididos. Faltam:
   - a sequência de bootstrap entre build e start (H1);
   - portas, volumes e durabilidade em `down/up` (H2);
   - CI/CD (C1);
   - a segurança das web apps (M6);
   - os limiares do sweeper (M10);
   - o reset de dados entre execuções do Benchmark (L6).

## Achados

### Crítico

**C1 — Os workflows do brownfield publicam imagem derivada do AI Hub em registry público e fazem deploy no Cloud Run.**
- **Onde:**
  - `.github/workflows/github-registry.yml` publica `ghcr.io/${{ github.repository }}:latest` a cada push em `master`;
  - `.github/workflows/build-push-gcr.yaml` faz deploy no Cloud Run via `demo-deployment`;
  - `.github/workflows/bump-module-version.yml` faz auto-commit, já ativo (veja `efb4f61 auto bump version`);
  - `.github/workflows/runtests.yml` monta a imagem no GitHub, onde o build 154 não pode ser puxado.
  - O spine, no Structural Seed ("Ambientes: … Não há registry público"), afirma o contrário e não trata CI/CD.
- **Por que é crítico:** FR-42 e o edital (PRD §7) proíbem publicar a imagem do AI Hub ou uma derivada em registry público. Hoje a publicação só não ocorre porque o `FROM` vai falhar no runner. Se alguém trocar o `ARG IMAGE` para um build pullable, ou se o runner tiver a imagem, a violação acontece em silêncio. Além disso, o CI ficará vermelho em todo push, e o auto-bump continuará gerando commits durante o concurso.
- **Correção:** acrescentar ao Structural Seed um bloco "CI/CD" (ou um AD-20 `[ADOPTED]`) com a regra: *"Nenhum workflow publica imagem ou faz deploy. `github-registry.yml` e `build-push-gcr.yaml` são removidos. `runtests.yml` é removido ou substituído por um job sem Docker (lint/`objectscript-quality`), porque o build 154 não existe no runner. `bump-module-version.yml` é removido ou fica restrito a `release`."* Vincular a regra a FR-42.

### Altos

**H1 — A sequência de bootstrap (build × start) está indefinida, com risco de embutir a chave do Provedor na imagem.**
- **Onde:**
  - AD-18 ("Na inicialização, um passo único materializa…");
  - Consistency Conventions → Configuração ("lidas na inicialização");
  - Structural Seed → Imagem.
- **Problema:** no brownfield, todo o `iris.script` roda **em `docker build`** (`Dockerfile`, `RUN --mount … iris session IRIS < iris.script`), sem `.env`, e o `docker-compose.yml` não tem `env_file`. Se uma frente puser a materialização do AI Hub (Wallet/Config Store/`%AI.Provider.Create`) no `iris.script` ou num `Invoke` do IPM, a chave fica em uma camada da imagem e no banco dela. Isso viola FR-44 e §6. O mesmo vale para outros passos que ninguém posicionou:
  - criação das web apps (`/signalnoir/api/v1`, `/sim/api/v1`, SPA);
  - autostart da Production;
  - registro da tarefa sweeper.
- **Correção:** criar um AD "Bootstrap em dois tempos":
  - **Build** (`iris.script` + `zpm load`): compila o código, cria namespace, web apps e Production com AutoStart, e registra a tarefa `%SYS.Task`. Nunca lê segredo.
  - **Start**: `env_file: .env` no compose. Um passo único em `%ZSTART` (ou na Production `OnStart`, escolher um) lê o ambiente do processo de start e materializa o Provedor. É idempotente a cada boot.
  - Proibir explicitamente qualquer leitura de chave durante o build.

**H2 — O compose do brownfield contradiz o seed de implantação: o bind mount esconde o estático, as portas são aleatórias e a durabilidade em `down/up` não foi decidida.**
- **Onde:** Structural Seed → Implantação e Imagem; `docker-compose.yml` (`volumes: - ./:/home/irisowner/dev`; `ports: - 1972 - 52773 - 53773`).
- **Problema:**
  - **Estático escondido.** O build multi-stage "copia o estático" para a imagem. Se o destino estiver sob `/home/irisowner/dev`, o bind mount do compose o esconde em runtime, e a máquina do jurado não terá `ui/build`.
  - **Portas aleatórias.** `ports: - 52773` publica numa porta aleatória do host, e o README não consegue dar uma URL fixa (FR-43, NFR-10).
  - **Durabilidade.** Os bancos ficam em `/data/IRISAPP_DATA` dentro do container, sem volume. FR-4 e NFR-5 ("reiniciar o container") valem para `docker compose restart`, mas não para `down`/`up`. O spine não diz qual dos dois é o contrato.
- **Correção:** no Seed, decidir:
  - (a) o compose da submissão não monta `./` (o mount de dev fica num `docker-compose.override.yml` opcional), ou o estático é copiado para fora do mount, por exemplo `/usr/irissys/csp/signalnoir`;
  - (b) portas fixas `52773:52773` e `1972:1972`, com `53773` removida;
  - (c) volume nomeado para `/data` (e para `ISC_DATA_DIRECTORY`, se a tarefa e a Production precisarem sobreviver a `down`), ou a declaração explícita de que o contrato de reinício é `docker compose restart`. Citar FR-4 e NFR-5.

**H3 — A semântica de retry e tentativas do Execution BO está aberta, e AD-8 proíbe timers que o fluxo exige.**
- **Onde:** AD-5 (passos 1 a 4); AD-8 ("Nenhum outro componente tem timer próprio"); `addendum.md` §D (`Executing → Failed: Tentativas da Política esgotadas`).
- **Problema:** um BO da Production com adapter HTTP tem retry nativo (`ReplyCodeActions`, `RetryInterval`, `FailureTimeout`) que reenvia sem passar pela Reconciliação. Uma frente que deixe o default reabre o efeito duplicado que AD-5 quer impedir. Além disso, "Tentativas da Política" com espera entre tentativas precisa de um relógio, o que AD-8 proíbe sem dizer quem reagenda.
- **Correção:** acrescentar ao AD-5:
  - *"O Execution BO roda com retry nativo desligado (`ReplyCodeActions` sem `R`, `Retry`/`FailureTimeout` neutros). Cada Tentativa é um comando explícito. Qualquer erro, timeout ou resposta incerta leva primeiro à Reconciliação (passo 4), nunca a reenvio direto."*
  - Escolher quem agenda a próxima Tentativa: o sweeper, por uma passada "Tentativas devidas", ou o BP, com espera explícita registrada na Linha do Tempo. Ajustar AD-8 para reconhecer essa exceção ou incluir a passada.

**H4 — O Modo Regras mora em `SignalNoir.Bench`, mas é invocado pela Investigação em `Interop`, o que cria um ciclo e confunde a propriedade.**
- **Onde:** Árvore mínima (`Bench/ # executor do Benchmark, Modo Regras, relatório`); AD-9; diagrama do Design Paradigm (`BENCH -->|comandos| INTEROP`).
- **Problema:** AD-9 diz que a Investigação (BO em `Interop`) invoca a implementação `rules` ou `agent`. Se `rules` está em `Bench`, `Interop` depende de `Bench`, e `Bench` já depende de `Interop`. Isso viola "dependências só apontam para dentro". Também cruza frentes: pelo PRD §9.5, Bench é do Henry e a Investigação é do José. FR-48 exige que o Modo Regras use as mesmas Ferramentas, ou seja, a mesma porta, e não um executor de Benchmark.
- **Correção:** criar `SignalNoir.Proposers` (ou `Application.Proposers`) com a interface da porta e as implementações `Rules` e `Agent` (e `Replay`, ver M4). `Bench` só escolhe o modo na criação do Caso. Atualizar o diagrama, a árvore e a lista de pacotes das Conventions. Atribuir dono por pacote.

**H5 — O formato dos DTOs de Proposta e Evidência foi adiado, mas é o contrato entre unidades escritas por pessoas diferentes.**
- **Onde:** Deferred ("Formato interno das mensagens da Production e dos DTOs: a definir pelo código, desde que respeite AD-6 e AD-9").
- **Problema:** AD-9 depende de "o mesmo DTO de Proposta" para as implementações `rules` e `agent`. FR-48 manda as regras serem escritas ou revisadas por outro integrante. O mesmo DTO alimenta o Validador (AD-12), o export do Benchmark (FR-8) e a UI via API. Deixar esse formato "para o código" é exatamente o ponto em que duas frentes divergem.
- **Correção:** tirar do Deferred e fixar nas Conventions uma classe única dona, por exemplo `SignalNoir.Core.Dto.Proposal` e `SignalNoir.Core.Dto.Evidence`, com os campos mínimos de FR-12 e do Glossário:
  - Proposta: `diagnosis`, `action`, `params`, `scope=single_case`, `confidence ∈ {ALTA, MEDIA, BAIXA}`, `preconditions[]`, `hypotheses[]`, `evidenceRefs[]`, `author`, `policyVersion`, `promptVersion`, `provider`, `model`, `tokens`;
  - Evidência: `source`, `at`, `params`, `result`, `suspicious`.
  
  Só o formato das *mensagens* internas da Production continua adiado.

**H6 — Nada isola o Gabarito e o controle de Cenário das consultas do propositor.**
- **Onde:** AD-13 (o HTTP do Simulador serve ao mesmo tempo a entrega, as consultas das Ferramentas e "o controle de semente e variante feito pelo Benchmark"); FR-32 e FR-33.
- **Problema:** a tese depende de o Agente e o Modo Regras não verem o Gabarito, a semente ou o identificador da variante. A mesma API e o mesmo banco servem o plano de dados e o plano de controle. Uma Ferramenta mal escrita (`status do Pedido na Origem`, `Linha do Tempo`) pode vazar o rótulo da variante ou do Gabarito, e o placar perde a honestidade (§10).
- **Correção:** emenda ao AD-13:
  - *"A API do Simulador tem dois prefixos: `/sim/api/v1/data` (Parceiro, Origem e fontes de Evidência), alcançado pelo Execution BO e pela porta de Ferramentas, e `/sim/api/v1/control` (semente, variante, reset), alcançado só pelo Bench."*
  - *"O Gabarito fica fora do Simulador, nas fixtures versionadas do Bench, e nenhuma resposta do plano de dados contém o identificador da variante."*
  - Refletir isso no `openapi-sim.yaml` (AD-16).

### Médios

**M1 — O orçamento de tempo do NFR-1 não é aplicável pela porta de Ferramentas.**
- **Onde:** AD-10 ("aplica o orçamento (NFR-1) por contagem e por tempo"); AD-11.
- **Problema:** `Chat()` é síncrono e bloqueante (research-stack §1.2). Uma única chamada ao LLM pode passar de 20 s sem que nenhuma Ferramenta seja chamada, e a porta só vê o relógio quando é chamada. Também não estão decididos o pool do BO de investigação e o `ResponseTimeout` da chamada BP → BO, que dependem de NFR-2 e da concorrência do Benchmark.
- **Correção:** dividir a regra em duas:
  - a contagem fica em `Tools`;
  - o tempo é imposto pelo BP, com chamada ao BO de investigação com timeout de 20 s, que leva a `ReviewRequired "orçamento excedido"`, e pelo timeout HTTP do Provedor.
  
  Fixar o `PoolSize` do BO de investigação e dizer se o Benchmark roda Casos em série ou em paralelo.

**M2 — Falta uma proteção contra resultado tardio de Investigação.**
- **Onde:** AD-3 (tupla do CAS: `caseVersion`, estado, `proposalVersion`/`executionId`).
- **Problema:** depois de um timeout (M1) ou de um reinício, o BO de investigação antigo pode terminar e gravar uma Proposta. Se nesse meio-tempo o Caso voltou a `Investigating` (addendum §D: "qualquer não terminal → Investigating" por nova Exceção), estado e versão podem bater de novo. Isso acontece se a versão foi relida pelo job tardio ou se o comando usa a versão corrente.
- **Correção:** acrescentar `investigationId` (prefixo `inv_`) à tupla do AD-3. A gravação da Proposta exige que `investigationId` seja o vigente do Caso.

**M3 — AD-2 é autocontraditório.**
- **Onde:** AD-2 ("Cada comando faz uma transição… Não existe transição sem evento nem evento sem transição").
- **Problema:** FR-7, AD-10 e FR-3 exigem eventos sem mudança de estado: Chamada de Ferramenta, nova Exceção num Caso já em `Investigating`, atualização da cópia do Recibo (AD-14) e Evidência obsoleta (FR-6). Do jeito que está escrita, a regra é inaplicável ou força transições fictícias.
- **Correção:** reescrever assim: *"Todo comando grava, na mesma transação, ≥ 1 evento da Linha do Tempo. Toda mudança de estado é uma transição permitida e gera evento. Comandos sem mudança de estado (lista fechada: `EvidenceRecorded`, `ExceptionRegistered`, `ReceiptSnapshotUpdated`, …) incrementam `caseVersion` e gravam evento."*

**M4 — Replay (FR-41) e validação rápida (FR-49) não têm casa arquitetural.**
- **Onde:** AD-9 (`rules` ou `agent`); AD-19 (`replay = true`); Capability Map (linha FR-39 a FR-41, FR-48, FR-49 → "Bench").
- **Problema:** não está decidido onde as respostas gravadas do Agente substituem o Provedor (no BO de investigação? no Bench?). Também não está decidido se FR-49 chama o Provedor do jurado ou roda em Replay. Duas frentes vão implementar isso de formas diferentes.
- **Correção:** declarar `replay` como terceira implementação da porta de proposição (H4), alimentada por gravações versionadas da Execução de Referência, com `replay = true` definido pelo Bench na criação do Caso. Dizer explicitamente qual modo FR-49 usa e onde ficam as gravações (por exemplo `bench/reference/`).

**M5 — O status de FR-53 diverge do PRD.**
- **Onde:** Questões em aberto, Q-B ("Se não, vale o FR-53"); AD-10 (`%AI.ToolSet`); PRD §9 ("Foi adotado o plano B de Evidência Pré-coletada (FR-53)", cortes de 18/10) e PRD §9.4 (decisão no spike).
- **Problema:** o próprio PRD é ambíguo, e o spine escolheu o lado condicional sem dizer isso. As frentes podem construir o caminho de ToolSets como base e o plano B como acessório, ou o contrário.
- **Correção:** declarar no AD-9 ou no AD-10 que a **base da v1 é o pacote Pré-coletado com segunda rodada determinística (FR-53)**. As Ferramentas chamadas pelo Agente via `%AI.ToolSet` são um incremento opcional, condicionado a Q-B, pela mesma porta. Registrar a decisão no memlog e pedir que o PRD corrija o §9 ou o §9.4.

**M6 — A segurança das web apps não foi decidida.**
- **Onde:** Deferred ("Autenticação e perfis: fora"); Seed (web apps SPA, `/signalnoir/api/v1`, `/sim/api/v1`).
- **Problema:** "sem perfis" não diz se as web apps são `Unauthenticated` ou `Password`. O brownfield usa `_SYSTEM/SYS` (Dockerfile `ENV IRISPASSWORD`) e tem o `passwordless` comentado no `iris.script`. A UI, a API e os clientes HTTP da Production (Execution BO, Tools → Sim) precisam concordar sobre credenciais. Sem isso, um vai mandar Basic Auth e outro não.
- **Correção:** convenção explícita:
  - as web apps `/signalnoir/*` e `/sim/*` são `Unauthenticated`, com `MatchRoles` restrito a um papel de aplicação, por exemplo `SignalNoirApp`, e sem acesso a `%All`;
  - o Management Portal mantém a senha padrão documentada no README;
  - os clientes HTTP internos não enviam credencial.

**M7 — Não há convenção de correlação para o Visual Trace (FR-37) nem para o identificador de correlação (FR-1).**
- **Onde:** AD-6 (comando com `caseId`, `caseVersion`, tipo); AD-15; Conventions → IDs.
- **Problema:** um Caso atravessa várias sessões da Production, porque o BS de entrada e o BS de comandos abrem sessões novas. FR-37 pede um link que leve "às mensagens do Pedido". Nada obriga as mensagens a carregar `correlationId`/`caseId` nem o Caso a guardar os `SessionId`. A UI e a Interop vão inventar soluções diferentes.
- **Correção:** convenção com três partes:
  - toda mensagem da Production estende uma base com `caseId` e `correlationId` (prefixo `corr_`, gerado em FR-1);
  - cada `SessionId` novo é gravado como evento `ProductionSessionLinked`;
  - a UI linka para o Visual Trace da sessão mais recente e para a busca de mensagens filtrada por `correlationId`.

**M8 — A Aprovação na resolução pelo Operador (FR-29) e a resposta à Aprovação repetida (FR-19) não foram decididas.**
- **Onde:** AD-3 (409 `STALE_VERSION`); Capability Map (FR-28 e FR-29); addendum §D (`ReviewRequired → DecisionProposed`).
- **Problema:**
  - Não está decidido se uma Ação escolhida pelo Operador para um efeito externo exige uma Aprovação separada ou se a escolha já vale como Aprovação. FR-16 diz que todo efeito externo exige Aprovação.
  - Um segundo clique na mesma versão pode receber 409 ou 200 idempotente, e a UI precisa saber qual.
- **Correção:** decidir e registrar no Core:
  - (a) a resolução pelo Operador gera uma Proposta `author=operator:<nome>` mais uma Aprovação implícita do mesmo autor, registradas como dois eventos, **ou** passa por `PendingApproval` normal;
  - (b) uma Aprovação repetida da mesma `proposalVersion` pelo mesmo resultado devolve 200 idempotente com a Aprovação existente, e só uma versão diferente devolve 409.

**M9 — A identidade da imagem e o IPM não estão fixados.**
- **Onde:** Stack (`IPM (ZPM) | latest`); Seed → Imagem ("retagueada"); `Dockerfile` (sete linhas `ARG IMAGE`, a última `intersystems/iris-community:latest-cd`); Q-E aberta.
- **Problema:**
  - FR-43 exige o retag "para a tag exata usada pelo compose", e o spine não fixa a tag. O README, o `Dockerfile` e o compose podem divergir.
  - O `wget …/zpm/latest/installer` torna o build não reprodutível entre o jurado e o time.
  - O `latest-cd` atual puxaria uma imagem errada sem erro.
- **Correção:**
  - fixar a tag local, por exemplo `signalnoir/iris-aihub:2026.3.0AI.154.0`, em que o README faz `docker tag <imagem carregada> signalnoir/iris-aihub:…`;
  - deixar um único `ARG IMAGE` com essa tag;
  - fixar a versão do IPM (URL `/packages/zpm/<versão>/installer`);
  - registrar Q-E como dependente desse nome.

**M10 — O sweeper tem limiares e roteamento de órfãos indefinidos.**
- **Onde:** AD-8 ("varredura de Casos órfãos ou vencidos em estados intermediários").
- **Problema:**
  - Não há limiar por estado. Uma Investigação legítima dura até 20 s, e a tarefa roda a cada 60 s.
  - Não há regra de destino. Um órfão em `Executing` depois de um reinício precisa ir à Reconciliação, nunca a reenvio. FR-4 manda `Investigating` interrompido ir para `ReviewRequired`. `Approved` sem comando entregue precisa de reentrega.
  - Cada frente vai decidir isso no código do sweeper ou no BP.
- **Correção:** tabela no AD-8:

  | Estado | Limiar | Destino |
  | --- | --- | --- |
  | `Investigating` | > NFR-1 + margem | `ReviewRequired "investigação interrompida"` |
  | `Approved` | > N s sem evento de Execução | reentrega do comando |
  | `Executing` | > timeout do Parceiro | comando de Reconciliação |
  | `Held` | 60 s | Reavaliação |

  Também fixar como o intervalo é configurado no `%SYS.Task`: frequência diária em minutos, mínimo de 1 min.

### Baixos

**L1 — A tabela Stack está incompleta.**
- **Onde:** Stack.
- **Problema:** falta o TypeScript `^6.0.0` (peer do SvelteKit 3.1.0, research-stack §2) e `@sveltejs/vite-plugin-svelte 7.3.1`. Não está dito se o Embedded Python é usado. O `merge.cpf` habilita `%Service_CallIn` para ele.
- **Correção:** acrescentar as duas linhas e declarar "Embedded Python: não usado na v1" (ou o contrário).

**L2 — Os nomes do brownfield não foram ratificados.**
- **Onde:** Pacotes e Árvore mínima × `module.xml` (`dc-sample`, `Resource dc.sample.PKG`, `UnitTest Package="dc.sample.unittests"`), `merge.cpf` (`SystemMode=IRIS Dev Template`; o template do AI Hub usa `AI Hub EAP`), `src/dc/sample/*`, `Dockerfile_mini` e `Dockerfile_less_image`.
- **Correção:** dizer no Seed:
  - o módulo vira `signal-noir`, com `Resource SignalNoir.PKG` e `UnitTest Package="SignalNoir.Tests"`;
  - o namespace `IRISAPP` é mantido (ou renomeado, mas decidir);
  - o sample, `Dockerfile_mini` e `Dockerfile_less_image` são removidos;
  - o `SystemMode` segue o template do AI Hub.

**L3 — O adiamento do mecanismo de CAS só é seguro com um repositório único.**
- **Onde:** Deferred ("Mecanismo concreto do compare-and-swap").
- **Correção:** acrescentar *"implementado num único repositório de `SignalNoir.Application`; nenhum outro pacote usa `%Save` ou `UPDATE` em classes do Caso"*. Isso torna o adiamento inofensivo.

**L4 — A convenção de IDs está incompleta.**
- **Onde:** Conventions → IDs.
- **Problema:** faltam os prefixos de `Attempt`, `Investigation` e correlação (`att_`, `inv_`, `corr_`), e as Exceções não têm prefixo.
- **Correção:** completar a lista.

**L5 — A fórmula da Chave de Idempotência não foi fixada.**
- **Onde:** AD-5, passo 3.
- **Problema:** FR-22 diz "estável por Pedido e Ação autorizada", mas não diz se, depois de `Held → Investigating → nova Aprovação` da mesma Ação, a chave se repete. O Simulador (Henry) e o Execution BO (José) precisam concordar.
- **Correção:** fixar a fórmula, por exemplo `hash(orderId, action, params canônicos)`, independente de `approvalId`, e registrá-la no `openapi-sim.yaml`.

**L6 — Não há operação de reset e purge.**
- **Onde:** ausente; tem relação com FR-40 (k = 3) e FR-49.
- **Problema:** não está dito como limpar Casos, sessões `%AI.Agent.Session` e mensagens da Production entre execuções do Benchmark, nem se o jurado pode repetir FR-49 sobre uma base suja.
- **Correção:** um comando de reset no Bench que só usa Application e `/sim/api/v1/control`, mais o purge de mensagens da Production, documentado no README.

**L7 — O limite de tipos do ToolSet não foi refletido.**
- **Onde:** AD-10.
- **Problema:** o schema XML do `%AI.ToolSet` aceita só string, number e boolean (research-stack §1.6).
- **Correção:** as assinaturas da porta de Ferramentas expostas ao Agente usam só esses tipos, com resultados serializados em JSON string.

**L8 — FR-18 (validade da Aprovação) não aparece no mapa.**
- **Onde:** Capability Map.
- **Problema:** não está dito que a expiração é verificada na Revalidação (`Approved → PendingApproval`, addendum §D) em vez de um timer, o que é coerente com AD-8.
- **Correção:** acrescentar a linha "FR-18 → Core (Revalidação) | AD-5, AD-8".

## Pontos fortes (para preservar)

- AD-2, AD-3 e AD-5 juntos fecham o problema central de efeito duplicado. As reações a conflito estão definidas por adaptador.
- AD-9 e AD-12 tornam o Benchmark uma comparação de decisões, não de implementações.
- AD-15 separa com honestidade o que o Visual Trace consegue provar do que fica com a Linha do Tempo.
- AD-17 e AD-18 incorporam limitações reais do build 154 que o research-stack encontrou (falta de fallback de deep link, issue #31).
- As questões em aberto têm responsável e data (spike de 25/10).

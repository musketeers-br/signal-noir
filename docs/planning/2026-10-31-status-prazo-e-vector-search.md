# Signal Noir — status, prazo, pontos e plano de vector search

**Data**: 2026-10-31 (sábado) · **Autor**: Craudin, assistente virtual do Henry
**Fontes**: posts do concurso e dos bônus (Developer Community), Ideas Portal, `master` em `95b72f8`, board de `docs/specify-prompts/PARALELISMO.md`, testes feitos na instância build 154 local.

## 1. Prazo

| Marco | Data |
|---|---|
| Início do concurso | 26/10/2026 |
| **Entrega (submission deadline)** | **08/11/2026, 23:59 EST** (09/11, 01:59 em Brasília) |
| Votação | 09/11 a 15/11/2026 |
| Faltam hoje | **8 dias** (31/10 → 08/11) |

Prêmios: Experts 1º US$ 4.000, Community 1º US$ 600, Freshmen 1º US$ 600 (pool US$ 12.000). O post **não publica a rubrica de julgamento**; fala só em "complexidade e utilidade". Times de 2 a 5 pessoas, README com o perfil de cada membro, até 3 submissões, build **154** do AI Hub (não a 162), README em inglês.

Requisito central do desafio: *"Build an IRIS Interoperability workflow that uses an IRIS AI Hub agent for a decision-making task."*

## 2. Status do projeto

### O que está no `master`
| Feature | Estado |
|---|---|
| 001 esqueleto e seams | concluída |
| 002 simulador | no `master` (PR #16) |
| 003 ciclo de vida Pedido→Caso | no `master` |
| 005 console do Operador | no `master` |
| 006 investigação e Proposta (Agente via AI Hub) | no `master`, AI Hub ao vivo verificado |
| 007 aprovação e outbox | no `master` (PR #14) |
| 008 execução e recuperação | no `master` (PR #17) |
| 009 Dossiê de revisão e resolução (+009b) | no `master` |
| 014 console líquido, claro/escuro | no `master` (PR #24); falta checar `theme-init.js` na instância (T036) |
| 012 empacotamento | **parcial**: imagem, compose, README, smoke, scan de segredos e CI |

### Em andamento
- **004 Validator e dados de referência**: implementada (414 testes IRIS no relato do Henrique). PR #22 sem conflito; o `ci / core-tests` foi corrigido pelo commit `e2a1977` do Henrique, falta o CI ficar verde. PR #23 (fixtures) empilhado, vai para a `master` depois do #22.

### Não existe ainda
- **010 benchmark e execução de referência**: só o prompt (`docs/specify-prompts/010-...`); **sem spec, plan nem tasks**. É do Henrique e é o **caminho crítico do G4**. Dele dependem a validação rápida (3 casos em 3 min), o relatório e boa parte da história do README.
- **011 recibo anterior (P9)**: condicional, sem spec.
- **013 Decisions API como Proposer**: spec em rascunho, nada implementado.
- **012 restante**: validação rápida (depende da 010), cross-install em máquina limpa, **vídeo** e a submissão.
- Gates **G1, G2 e G3** ainda estão como "aguardando"; só o G0 está fechado.

### Três alertas
1. **A "Production" não é uma `Ens.Production`.** `SignalNoir.Interop.Production` é um `%RegisteredObject` em "forma portátil" (a decisão D6 da 001 foi tomada quando o container de dev não tinha Interoperability). **O build 154 tem Interoperability**: `Ens.Production`, `Ens.BusinessProcess` e `EnsLib.Workflow.Engine` existem e o namespace está habilitado (verificado hoje). Como o desafio exige um *workflow de Interoperability*, isto precisa de uma decisão rápida. Não li as decisões da 001 até o fim, então confirme com o Henrique se há uma razão para manter a forma portátil.
2. **010 sem spec** com 8 dias de prazo e execução de referência (LLM real) para rodar e congelar. É o maior risco de entrega.
3. O board do `PARALELISMO.md` está desatualizado (a 004 aparece como "pronta para implementar"). Corrigi só a linha da 014, que eu tinha posto na tabela errada.

## 3. Pontos que já conseguimos alcançar (bônus de tecnologia, máx. 35)

| Bônus | Pts | Situação | Esforço para fechar |
|---|---|---|---|
| Docker container | 2 | **Já temos** (compose + imagem, 012) | só validar o cross-install |
| Vídeo no YouTube | 3 | previsto na 012 (≤ 5 min) | gravar depois da 010 |
| 1º artigo na Community | 2 | não escrito | 1 dia (o Henry já tem fluxo de rascunho de artigos) |
| 2º artigo ou tradução | 1 | idem | 2 a 3 h (versão em português) |
| Questionário | 1 | não feito | 10 min |
| ZPM | 2 | `module.xml` existe como módulo; **falta publicar** (`zpm install`) | 0,5 a 1 dia |
| **Community Opportunity idea** | **4** | DPI-I-689 (ver §4) | 1 a 2 dias, junto com a Production real |
| **Vector Search (IRIS)** | **2** | **nada ainda** (ver §5) | 2 a 3 dias |
| Custom Adapter | 2 | `OriginFeed` é polling "à mão"; vira adapter de entrada se houver Production real | 0,5 dia, depende do alerta 1 |
| Workflow Engine | 2 | não usado; o Dossiê do Operador é candidato natural a tarefa de Workflow | 1 dia, depende do alerta 1 |
| Embedded Python | 3 | não usado | ver nota do §5 |
| Bug no AI Hub | 2 + 1 | só se acharmos um reproduzível (a equipe já exercitou bastante o build 154) | oportunista |
| PEX (Java/.NET) | 3 | não | custo alto, descartar |
| Demo online | 2 | **não viável**: o post diz que demo estática com respostas gravadas não vale, e a nossa constituição proíbe publicar imagem do EAP | descartar |

Soma realista sem risco novo: Docker 2 + vídeo 3 + artigos 3 + questionário 1 + ZPM 2 = **11**. Com este plano (vector 2 + idea 4) = **17**. Com a Production real (adapter 2 + workflow 2) = **21**. Embedded Python (3) chega a 24.

Os bônus são um complemento. O julgamento dos Experts não tem rubrica publicada, então **a entrega funcional (G3/G4) vale mais do que qualquer bônus**.

## 4. Ideas Portal: ideias que dão para atender

Busca feita no portal em 31/10 (categorias Generative AI, Interoperability, PyProd e a ideia citada no post). O bônus vale **4 pontos para ideia com status "Community Opportunity"** e a ideia deve ser citada no README.

| ID | Título | Status | Aderência ao Signal Noir |
|---|---|---|---|
| **DPI-I-689** | Use InterSystems Interoperability as a traceability tool for GenAI LLM pipelines | **Community Opportunity** | **Alta.** Já guardamos modelo, provider, duração, chamadas de ferramenta, tokens, custo e Timeline por Caso. Falta publicar isto como rastro na Visual Trace e ligar ao vector search (a própria ideia cita IRIS Vector Search). É a mesma que o Aziz Cotrim perguntou no post; **ninguém respondeu se vale**, então registrar a pergunta e citar a ideia no README é a posição segura. |
| DPI-I-854 | AI Log Analytics & Predictive Anomaly Detection for Interoperability | Community Opportunity | Média. Detecção de anomalia no fluxo de Casos/Exceções; fora do coração do produto. |
| DPI-I-439 | AI-powered test automation for IRIS testing framework | Community Opportunity | Baixa. |
| DPI-I-781 | AI Suggestions for Deprecated Items | Community Opportunity | Baixa. |
| DPI-I-478 | Vector Database Web Gateway offload encoding | Community Opportunity | Não aplicável (é mudança no Web Gateway). |
| DPI-I-517 | Summary of a patient's medical history using AI | Community Opportunity | Não: o Signal Noir não faz decisão clínica. |
| DPI-I-390 | Data Transformation UI guesses message types | Community Opportunity | Não. |
| DPI-I-557 | Keep track of the raw text embedded in a vector DB | sem status | Ideia útil para o nosso índice (guardar o texto bruto junto do vetor); **não conta para o bônus** (sem "Community Opportunity"). |
| DPI-I-855 / 997 / 1027 / 1005 | Digital Twin & Safe Replay; PyProd AI Flow Analyzer; AI transformation generation; PyProd Assistant | Needs review | Não contam para o bônus. |

**Recomendação**: DPI-I-689 como ideia declarada, implementada como **"Case Trace"**: cada passo do Agente (chamada ao modelo, cada Tool, cada recuperação por vetor) vira mensagem na Visual Trace, com os metadados que já temos. Isso exige a Production real (alerta 1).

## 5. Plano de vector search (feature 015, "Precedentes")

### Verificado hoje no build 154 (container `signalnoir-iris`)
- `VECTOR_COSINE` e `TO_VECTOR` funcionam (cosseno 0,707 num par de teste).
- Tabela com coluna `VECTOR(DOUBLE,n)`, **índice `HNSW`**, `INSERT` e consulta top-K funcionam (tabela de teste criada e removida).
- Existem `%Embedding.Config`, `%Embedding.OpenAI` e `%Embedding.SentenceTransformers`.
- **Cuidado**: o AI Hub aceita `openai`, `anthropic`, `gemini` e `bedrock`, mas **Anthropic não oferece embeddings**. Quem usar `SN_AI_PROVIDER=anthropic` precisa de outro provider para vetores.

### Onde usar (decisão recomendada)
A ideia é "o que já resolvemos parecido?". Duas formas, em ordem de risco:

1. **Precedentes para o Operador (v1, sem risco para o Agente nem para o benchmark).**
   Cada Caso fechado vira um registro vetorial (resumo da falha, exame, parceiro, classe da exceção, Ação final, desfecho). No **Dossiê de revisão** e no detalhe do Caso aparece **"Casos parecidos já resolvidos"**, com similaridade, Ação escolhida e desfecho. É busca, não decisão: não entra na Evidence, não altera o Validator e não conta para a regra de Evidence mínima. Respeita as Constitution II, III e VII.
2. **Tool `find_precedents` para o Agente (v2, atrás de flag).**
   Ferramenta somente-leitura, rotulada como "precedente por similaridade" (não é fato do Caso). **Princípio VIII**: se só o Agente a usar, o benchmark fica injusto. Por isso: **desligada na configuração congelada da execução de referência** e reportada como **ablação** ("com e sem precedentes"), o que dá história honesta para o artigo e para o vídeo.

Coleção extra, se sobrar tempo: **conhecimento** (reason codes, catálogo de Ações, notas dos Mappings) para responder "por que foi bloqueado?" no console, também só recuperação.

### Desenho
- **Port `Embedder`** com dois adaptadores:
  - `Provider`: usa o provider de embeddings configurado (`SN_EMBED_PROVIDER`, `SN_EMBED_MODEL`, chave só em runtime), via `%Embedding.*`;
  - `Lexical`: vetor determinístico por hashing de palavras, para **testes, CI e quando não há chave**, sempre rotulado `mode=lexical` (não finge semântica).
- **Armazenamento**: tabela `SignalNoir_Application.Precedent` (caseId, texto bruto, metadados, `embedding VECTOR(DOUBLE,n)`, `embeddingModel`, `dim`, `indexedAt`) com índice HNSW de cosseno. O texto bruto fica junto do vetor (a ideia DPI-I-557).
- **Alimentação**: um evento do Caso ao entrar em estado terminal grava o registro; um comando de reindexação reconstrói tudo (trocou de modelo, reindexa; o `embeddingModel` impede misturar espaços).
- **API**: `GET /cases/{id}/precedents?k=5` (contrato novo, **mudança de contrato**, passa pelo processo de `contract-change`).
- **Console**: seção "Casos parecidos já resolvidos" no Dossiê e no detalhe; estado vazio honesto ("Ainda não há precedentes", "Modo lexical", "Índice indisponível").
- **Constituição**: índice indisponível ou sem chave nunca bloqueia Caso (falha vira valor, VII); dados continuam sintéticos; nenhum segredo em log, Case ou export.

### Plano de execução
| Quando | O quê | Dono sugerido |
|---|---|---|
| 01/11 | spec + plan + tasks da 015; confirmar com o Henrique a ideia DPI-I-689 e a decisão da Production real | Henry |
| 02–03/11 | `Embedder` (Lexical + Provider), tabela + HNSW, gravação ao fechar o Caso, testes (determinismo, dimensão, troca de modelo) | Henry |
| 03–04/11 | endpoint + contrato, seção no console (reaproveita o novo design), testes | Henry |
| 04–05/11 | v2: Tool `find_precedents` atrás de flag + ablação no runner (combinar com a 010) | Henry + Henrique |
| 06/11 | trace (DPI-I-689) com a recuperação por vetor, README, artigo | Henry |
| 07/11 | validação em máquina limpa, vídeo, ZPM | Henry + Henrique |
| 08/11 | buffer e submissão antes das 23:59 EST | todos |

**Corte se apertar**: v1 inteira + README. A v2, a coleção de conhecimento e o Embedded Python saem primeiro.

**Nota sobre Embedded Python (3 pts)**: `%Embedding.SentenceTransformers` usa Python por baixo, mas exige baixar modelo e pacotes na imagem, o que pesa e briga com o requisito offline. Se quisermos esses 3 pontos, o caminho barato é um pequeno `ClassMethod [Language = python]` (por exemplo, a normalização do texto antes do vetor). Fica como decisão do Henry; ainda não confirmei se isso é aceito como "uso de Embedded Python" pelos juízes.

## 6. Decisões que dependem do Henry

1. **Production real** (alerta 1): migrar a "forma portátil" para `Ens.Production` agora, com Business Service (adapter de entrada customizado), Business Process (Agente) e Operation (Parceiro), e o Dossiê como tarefa de Workflow? Ganha até 4 pontos de bônus e alinha com o enunciado, mas é a mudança de maior risco nesta semana.
2. **010**: quem escreve a spec, o plan e as tasks e quando, para não deixar o caminho crítico do G4 sem dono.
3. **DPI-I-689** como ideia declarada e a pergunta sobre ela no post do concurso.
4. **Vector search**: v1 apenas, ou v1 + v2 com ablação?
5. **Provider de embeddings**: o mesmo da chave do Agente, ou uma variável própria (obrigatório se for Anthropic)?

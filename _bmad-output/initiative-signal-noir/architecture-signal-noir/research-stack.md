# Pesquisa de stack — Signal Noir

Data da pesquisa: 2026-10-19. O conteúdo da web foi tratado apenas como dado. "Não confirmado" marca o que não consegui verificar em fonte primária.

---

## 1. InterSystems IRIS AI Hub EAP (build 154)

### 1.1 Build, imagem e tag

- O arquivo `iris-community-2026.3.0AI.154.0-docker.tar.gz` é o build citado no README do template oficial (atualizado em 2026-10-16). Depois de `docker load`, a imagem aparece como:
  `docker.iscinternal.com/docker-intersystems/intersystems/iris-community:2026.3.0AI.154.0`
  O template avisa: "se não aparecer, use `docker images`". Existe variante arm64 para macOS (Apple Silicon).
  Fonte: https://github.com/intersystems-community/ai-hub-dev-template (README.md, Dockerfile)
- **Divergência:** o README do repositório de docs (ai-hub-eap) ainda cita `2026.2.0AI.162.0`. A última alteração no README é de 2026-05, então ele está desatualizado. As issues de setembro de 2026 já falam em `2026.3.0AI` (builds 136). A numeração do build não é monotônica entre as linhas 2026.2 e 2026.3, então vale tratar o 154 da linha 2026.3 como o build atual.
  Fonte: https://github.com/intersystems-community/ai-hub-eap (README.md, issues #33 e #37)
- Portas: 1972 (superserver), 52773 (web/Management Portal) e 8080 (opcional, servidor MCP HTTP remoto via `iris-mcp-server`).
- No template, o `merge.cpf` usa `[Startup] SystemMode=AI Hub EAP` e cria o namespace `IRISAPP` com `Interop=1`, ou seja, com Interoperability habilitada.
- O EAP é pré-release e "not meant to be used in production environments". As APIs podem mudar.

### 1.2 Como um agente é definido e invocado

- O agente é **nativo em ObjectScript**: uma subclasse de `%AI.Agent`.
  - **Declarativo:** usa os parâmetros `PROVIDER`, `MODEL`, `APIKEY`, `PROVIDERCONFIG`, `TOOLSETS` e `SKILLS` (este último experimental). O prompt de sistema fica em `XData INSTRUCTIONS [MimeType = text/markdown]`, que aceita templating `{{name}}` e `{{= expr}}`. O hook opcional é `%OnInit()`.
  - **Programático:** `##class(%AI.Agent).%New(provider)`, depois definir `Model`, `SystemPrompt` e `Temperature`.
- **Invocação** (síncrona e bloqueante):
  ```objectscript
  Set agent = ##class(App.MyAgent).%New()
  $$$ThrowOnError(agent.%Init())
  Set session = agent.CreateSession()
  Set response = agent.Chat(session, "...")   // %AI.LLM.Response; response.Content
  ```
  Também existem `StreamChat(session, input, callbackObj, callbackMethod)`, `ChatWithContent` (multimodal) e `Run(session, input, maxIter, monitor)`.
  - A sessão é a classe `%AI.Agent.Session`, que é `%Persistent`. Ela tem `%Save`/`%OpenId` e é restaurada com `%InitWithSession(session)`.
  - O loop do agente é limitado por `MaxIterations` (padrão 10).
  - Sub-agentes são criados com `DelegateTask()`. Esse recurso é experimental e as tarefas rodam em sequência.
  - Não há API assíncrona documentada.
- **Python:** o SDK Python é o pacote `langchain-intersystems`, distribuído como wheel no portal EAP. Ele implementa a API LangChain e roda **externo** ao IRIS, em um venv que se conecta via `iris.connect(host, 1972...)`. Configs de LLM/MCP são lidas do Config Store com `init_chat_model('openai', conn)` e `init_mcp_client([...], conn)`.
  - A doc não mostra agentes escritos em Embedded Python, nem `[Language = python]` em tools.
- **REST:** não existe endpoint REST documentado para "invocar um agente". O REST/WebSocket que existe é `%AI.MCP.Service`, uma classe de dispatch que expõe **tools** via MCP (rotas `/mcp/<app>/v1/services` e `/v1/tool_call`). Para chamar um agente por REST, é preciso criar um `%CSP.REST` próprio que chame `agent.Chat()`.
- Fontes:
  - https://github.com/intersystems-community/ai-hub-eap/blob/master/ObjectScript_SDK_Guide.md
  - https://github.com/intersystems-community/ai-hub-eap/blob/master/ObjectScript_SDK_Advanced.md
  - https://github.com/intersystems-community/ai-hub-eap/blob/master/langchain_SDK.md
  - https://github.com/intersystems-community/ai-hub-dev-template/blob/master/src/Sample/Agent.cls

### 1.3 Uso dentro de uma Production (Business Operation/Process)

- **Não há adapter nem BO/BP built-in para agentes.** Nenhum dos guias (SDK, Advanced, Examples, MCP Server, Config Store) cita `Ens.*`, `EnsLib`, Business Operation, Business Process ou adapter. O material de marketing fala em "integração com o feature set de interoperability", mas não aponta nenhuma classe.
  Fonte: https://www.intersystems.com/br/resources/intersystems-iris-ai-hub/
- **Inferência (não confirmado em doc, mas tecnicamente plausível):** como `%AI.Agent` é uma classe ObjectScript comum com chamada síncrona, um BO customizado (`Ens.BusinessOperation`, com ou sem adapter, por exemplo `Adapter = ""`) pode instanciar o agente em `OnMessage`/MessageMap e chamar `%Init()`/`Chat()`.
  - O namespace do template já vem com `Interop=1`.
  - Pontos de atenção:
    - O tempo de bloqueio do job do BO durante o loop do LLM. Ajuste o timeout de resposta e o pool.
    - O `ResponseTimeout` do chamador.
    - Variáveis de ambiente no job em background (issue #31). Prefira Config Store/Wallet a `@{env:...}`.
  - Validar com um spike no build 154.
- Uma tool MCP que invoca outro agente sofre timeout de 60 s quando é chamada via MCP REST/WebSocket. Quando é chamada direto em ObjectScript, funciona (issue #37, aberta, build 136). O `TIMEOUT` vale só para MCP.
- Na direção inversa, o README diz que um toolset pode conter "class methods, SQL or FHIR queries, and **Business Services**". Ou seja, uma Production pode ser **exposta como tool**.
  Fonte: README do ai-hub-eap.

### 1.4 Como tools são expostas ao agente

- **ToolSet:** subclasse de `%AI.ToolSet` (ou de `%AI.Tool`) com `XData Definition [MimeType = application/xml]`.
  - `<Tool Name="..." Method="..."/>` aponta para **ClassMethods**. O JSON Schema é gerado a partir da assinatura tipada, e as descrições vêm do doc comment ou do parâmetro `DESCRIPTION`.
  - `<Include Class Match Tool>`, `<Filter>` e `<Exclude>` compõem toolsets. `<Requirement>` adiciona metadados.
  - `<Query Name Description Arguments MaxRows>` define SQL inline com `:param` nomeado (o `?` posicional é rejeitado).
  - `Query ... As %SQLQuery [SqlProc]` em `%AI.Tool` define uma class query.
  - `<MCP Name><Stdio Executable><Env/></Stdio></MCP>` ou `<Remote URL>` usam um **servidor MCP externo**. Exemplo: o template usa um MCP stdio em Python com FastMCP.
- **Built-ins:** `%AI.Tools.SQL`, `%AI.Tools.FileSystem` e as URIs `rust:filesystem`, `rust:web_search`, `rust:shell`, `iris:%AI.Tools.SQL`, `mcp:stdio:...`.
- **Parâmetros de tool:** `REQUIRESAUTH`, `STATEFUL`, `TIMEOUT` e `DISCOVERYLIMIT`. As policies são `%AI.Policy.Authorization`, `ConsoleAuth`, `ConsoleAudit` e `Discovery`.
- O agente referencia o toolset com `Parameter TOOLSETS = "App.ToolSet"`.
- **Publicação MCP para clientes externos:** use uma web app com dispatch `%AI.MCP.Service` mais o binário Rust `iris-mcp-server` (que fica em `/usr/irissys/bin`), na porta 8080 por padrão no template.
- Fonte: ObjectScript_SDK_Guide.md ("Building Tools" e "Building ToolSets") e MCP_Server_Guide.md.

### 1.5 Configuração de provedores LLM

- **Provedores suportados** (string de nome):
  - `openai`, `anthropic`, `gemini`, `vertex`, `bedrock`, `meta`
  - `xai` (alias `grok`), `nim`, `deepseek`, `kimi` (alias `moonshot`), `openrouter`
  - `zai` (alias `glm`), `zhipu` (alias `bigmodel`)
  - Ollama e outros endpoints compatíveis com OpenAI funcionam via `openai` com `base_url`.
  - **Azure OpenAI:** não aparece listado (não confirmado; talvez funcione via `openai` com `base_url`).
- **Três formas de configurar:**
  1. **Direto:** `##class(%AI.Provider).Create("anthropic", {"api_key": "..."})`, atribuído a `..Provider` em `%OnInit()` (é o padrão do template).
  2. **Placeholders** em parâmetros:
     - `APIKEY = "@{env:OPENAI_API_KEY}"`
     - `@{wallet:Collection.Secret}`
     - `PROVIDERCONFIG = "@{config:AI.LLM.<Nome>}"`
     - O formato curto `@{config:Nome}` recebe o prefixo `AI.LLM` automaticamente.
     - É preciso chamar uma vez `##class(%AI.Utils.SettingStore).RegisterDefaults()`.
  3. **Config Store:** `##class(%ConfigStore.Configuration).Create("AI","LLM","","<nome>", {"model_provider":"openai","model":"gpt-4o","api_key":"secret://Coll.Secret#key"})`. O segredo fica no IRIS Wallet (`%Wallet.Collection` e `%Wallet.KeyValue`, com resources de Use/Edit). O provedor é carregado com `##class(%AI.Provider).CreateFromConfig("<nome>")`.
- **Variáveis de ambiente:** não há nomes fixos exigidos pelo SDK. O template usa `OPENAI_API_KEY`, passado por `.env`/`env_file` e lido com `$System.Util.GetEnviron`.
  - A doc diz que é preciso reiniciar o IRIS para ler a variável nova. A issue #31 contesta isso: processos em background podem não ver a variável.
  - Para segredos de verdade, use Wallet/Config Store.
- Fontes: ObjectScript_SDK_Guide.md ("Configuration Variables" e Overview) e https://github.com/intersystems-community/ai-hub-eap/blob/master/Config_Store_Guide.md

### 1.6 Limitações e issues conhecidas relevantes

Nenhuma release note específica do build 154 foi encontrada (não confirmado). Issues abertas no repositório (estado em 2026-10-19):

- **#33** `ERROR #26414: No descriptor found for AI.LLM / AI.MCP` no Config Store (build 2026.3.0AI.136). Não sei se foi corrigida no 154. Plano B: usar `%AI.Provider.Create` + Wallet/env.
- **#37** Um agente aninhado dentro de uma tool MCP sofre timeout após 60 s.
- **#34** O SDK falha ao conectar em servidor MCP remoto via HTTPS.
- **#30** O `base_url` padrão do OpenRouter vem sem `/v1`.
- **#32** O consumo de tokens é descartado em `run()` (no Python, usar `run_result()`).
- **#35** Não há controle de reasoning/thinking effort.
- **#31** A doc de variáveis de ambiente é enganosa.

Limitações documentadas:

- O schema de ToolSet XML aceita só string, number e boolean.
- Defaults de query não são aplicados.
- Modelos de reasoning rejeitam `Temperature`.
- Áudio só funciona com OpenAI.
- Skills, Planning, sessões avançadas e Smart Discovery são experimentais.
- RAG "will undergo significant change".

Fonte: https://github.com/intersystems-community/ai-hub-eap/issues

### 1.7 Embedded Python e IPM/ZPM

- **Embedded Python está disponível na imagem.** O Dockerfile do template configura `PYTHONPATH=/usr/irissys/lib/python`, instala pacotes com `--target /usr/irissys/mgr/python` e habilita `%Service_CallIn`, comentado como "for Embedded Python".
  - **Versão do Python: não confirmado.** Depende do SO base da imagem: Ubuntu 24.04 traz Python 3.12, Ubuntu 26.04 traz 3.14. Para verificar, rode `docker run --rm --entrypoint python3 <imagem> --version` ou, no terminal IRIS, `do ##class(%SYS.Python).Shell()` seguido de `import sys; sys.version`.
- **IPM/ZPM não vem pré-instalado.** O `iris.script` do template baixa e instala o ZPM em tempo de build a partir de `https://pm.community.intersystems.com/packages/zpm/latest/installer` e depois roda `zpm "enable -community"` e `zpm "load ..."`. Isso exige acesso à internet durante o build.
  Fonte: https://github.com/intersystems-community/ai-hub-dev-template/blob/master/iris.script

### 1.8 Repositórios auxiliares

- **iris-agentic-dev:** um binário Rust que atua como servidor MCP para ferramentas de coding (VS Code Copilot, Claude Code). Traz `contrib/aihub/IAD.ToolSet.xml`, que pluga essas tools em agentes AI Hub via `<MCP><Stdio>` e usa as variáveis `IRIS_HOST`, `IRIS_WEB_PORT`, `IRIS_USERNAME`, `IRIS_PASSWORD` e `IRIS_NAMESPACE`. Serve ao desenvolvimento e não é runtime da aplicação.
  Fonte: https://github.com/intersystems-community/iris-agentic-dev
- **ai-hub-dev-template:** contém Dockerfile, docker-compose, `merge.cpf`, `module.xml` (IPM) e exemplos `Sample.Agent`, `Sample.ToolSet`, `Sample.Tools` e `Sample.MCPService`, além de skills para agentes de código.
  Fonte: https://github.com/intersystems-community/ai-hub-dev-template

---

## 2. Versões estáveis do front-end (registro npm e nodejs.org, consultados em 2026-10-19)

| Pacote | Versão `latest` | Publicado em |
|---|---|---|
| svelte | **5.57.2** | 2026-10-06 |
| @sveltejs/kit | **3.1.0** | 2026-10-14 |
| @sveltejs/adapter-static | **4.0.0** | 2026-10-01 |
| vite | **8.3.4** | 2026-10-08 |
| @sveltejs/vite-plugin-svelte | 7.3.1 | 2026-09-23 |
| Node.js LTS | **v24.22.0 (Krypton, Active LTS)** | 2026-10-14 |

- SvelteKit 3.1.0 tem estas peerDependencies: `vite ^8.0.12`, `svelte ^5.57.1`, `@sveltejs/vite-plugin-svelte ^7.0.0` e `typescript ^6.0.0`. O engine exigido é `node >=22.17`.
- Node 22 (Jod) continua em manutenção LTS. O Node 26.x é a linha "Current" (v26.12.0) e deve entrar em LTS no fim de outubro de 2026 (não confirmado). Para build, use Node 24 LTS.
- **adapter-static existe e continua suportado.** A versão 4.0.0 exige SvelteKit 3. Ela gera um site estático e, com a opção `fallback` (por exemplo `fallback: '200.html'` ou `'index.html'`), produz uma **SPA pura** com shell vazio. Também aceita as opções `pages`, `assets`, `precompress` e `strict`. Para uma SPA, use `export const ssr = false` (e `prerender` conforme o caso) no `+layout.js` raiz.
- Fontes:
  - https://registry.npmjs.org/@sveltejs/kit
  - https://registry.npmjs.org/@sveltejs/adapter-static
  - https://github.com/sveltejs/kit/blob/main/packages/adapter-static/index.d.ts
  - https://github.com/sveltejs/kit/blob/main/packages/adapter-static/CHANGELOG.md
  - https://nodejs.org/dist/index.json

---

## 3. IRIS: arquivos estáticos, VERSIONPROPERTY e Task Manager

### 3.1 Servir uma SPA estática

- Uma web application do IRIS (`Security.Applications`) serve arquivos estáticos de um diretório usando as propriedades **CSP Files Physical Path** (`Path`) e **Serve Files** (`ServeFiles`): *No*, *Always*, *Always and cached* ou *Use InterSystems Security*. Esse mecanismo é padrão e consolidado.
- **Padrão recomendado:** duas web apps.
  - `/app` (ou `/`) sem Dispatch Class, com `Path` apontando para o `build/` do adapter-static e `ServeFiles` habilitado.
  - `/api` com `DispatchClass` apontando para a subclasse de `%CSP.REST`.
  - Quando a web app tem Dispatch Class, as requisições vão para o REST, então ela não serve como servidor de arquivos estáticos da SPA. Isso é o comportamento usual, mas não confirmei em doc da versão 2026.
- **Fallback de rotas da SPA (deep links):** o servidor de arquivos estáticos do CSP não tem rewrite nativo para `index.html`. Encontrei discussão na comunidade sobre isso, sem solução oficial. Opções:
  - (a) Usar roteamento por hash ou só a rota raiz.
  - (b) Criar uma rota catch-all em um `%CSP.REST` que devolve o `index.html`/`200.html` via `%Stream.FileBinary` ou `%CSP.StreamServer`.
  - (c) Fazer rewrite no web server/gateway externo (Apache/Nginx). A imagem community 2026 usa um web server privado mínimo (não confirmado).
- Fontes:
  - https://community.intersystems.com/node/532921
  - https://community.intersystems.com/node/507036
  - https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=GCSP_appdef (índice; a página de configuração não foi lida por completo)

### 3.2 VERSIONPROPERTY (concorrência otimista)

- **Confirmado.** O parâmetro `VERSIONPROPERTY` continua documentado em `%Library.Persistent` na doc "irislatest", rotulada IRIS 2026.2. Ele aponta para uma propriedade `%Integer` (com `InitialExpression = 0`) que o IRIS incrementa a cada save. Se a versão em memória diverge da versão gravada, o `%Save()` falha com erro de conflito de concorrência.
- A documentação da linha 2026.3 do AI Hub não foi verificada (não confirmado), mas o parâmetro pertence ao núcleo do `%Persistent`.
- Fonte: https://docs.intersystems.com/irislatest/csp/documatic/%25CSP.Documatic.cls?LIBRARY=%25SYS&CLASSNAME=%25Library.Persistent

### 3.3 Agendamento periódico

- **Confirmado.** O Task Manager é o mecanismo padrão. A tarefa é uma subclasse de `%SYS.Task.Definition` com:
  - `Parameter TaskName`
  - propriedades públicas, que viram configurações da tarefa
  - override de `OnTask() As %Status`
- O agendamento é feito pelo Management Portal (System Operation > Task Manager) ou por código via `%SYS.Task` (`%New`, `NameSpace`, `TaskClass`, `TimePeriod`/`DailyFrequency`..., `%Save`). Existe o parâmetro `RESOURCE` para controlar a permissão.
- Alternativa dentro de uma Production: um Business Service com `Ens.InboundAdapter` e `CallInterval`. Isso é comum, mas é outro padrão.
- Fonte: https://docs.intersystems.com/irislatest/csp/documatic/%25CSP.Documatic.cls?LIBRARY=%25SYS&CLASSNAME=%25SYS.Task.Definition (doc 2026.2)

---

## Resumo dos "não confirmado"

- Versão exata do Python embarcado no build 154.
- Release notes específicas do build 154. Também não sei se a issue #33 (descriptors do Config Store) foi corrigida.
- Uso de `%AI.Agent` dentro de um BO/BP: é plausível, mas não há doc nem exemplo oficial. Precisa de um spike.
- Suporte a Azure OpenAI.
- Data de entrada do Node 26 em LTS.
- Comportamento exato de `ServeFiles` em web app com Dispatch Class no IRIS 2026.x, e solução oficial para o fallback de SPA.

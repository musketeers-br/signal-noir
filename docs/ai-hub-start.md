# Subir o AI Hub — guia operacional

Como obter, carregar e subir a imagem do InterSystems AI Hub EAP build 154 para o Signal Noir.

> **EAP, download controlado.** O build 154 é pré-release e não está em registry público. A imagem
> vem do portal EAP da InterSystems e entra na máquina por `docker load`. O repositório nunca baixa
> a imagem, nunca puxa de `docker.iscinternal.com` e nunca publica uma imagem derivada.

## Pré-requisitos

- Docker com o plugin `docker compose`.
- Acesso ao portal EAP: <https://evaluation.intersystems.com/Eval/early-access/AIHub>.
- Os arquivos do build 154 para a sua arquitetura (x64 ou ARM64), por exemplo
  `iris-community-2026.3.0AI.154.0-docker.tar.gz`.
- Uma chave de um dos Provedores suportados pelo AI Hub (OpenAI, Anthropic, Gemini ou Bedrock).

O build **162 não é aceito**. Use o 154 da linha `2026.3.0AI`.

## 1. Carregar e retaguear a imagem

```bash
# x64
gunzip -c iris-community-2026.3.0AI.154.0-docker.tar.gz | docker load

# ARM64 (Apple Silicon)
gunzip -c <arquivo-arm64-do-build-154>.tar.gz | docker load

# confira a imagem carregada
docker images | grep 2026.3.0AI.154.0
```

Depois do load, a imagem aparece como:

```text
docker.iscinternal.com/docker-intersystems/intersystems/iris-community:2026.3.0AI.154.0
```

Retague para a tag fixa do projeto:

```bash
docker tag \
  docker.iscinternal.com/docker-intersystems/intersystems/iris-community:2026.3.0AI.154.0 \
  signalnoir/iris-aihub:2026.3.0AI.154.0
```

A tag `signalnoir/iris-aihub:2026.3.0AI.154.0` é a **única** usada pelo `Dockerfile`, pelo compose e
pelo README. Os dois arquitetos (x64 e ARM64) retagueiam para a mesma string.

## 2. Configurar o ambiente

```bash
cp .env.example .env
```

Preencha no `.env`:

```text
SN_AI_PROVIDER=<openai|anthropic|gemini|bedrock>
SN_AI_MODEL=<modelo-de-referencia>
SN_AI_API_KEY=<sua-chave>
```

- Os nomes acima são provisórios até o plan da spec `012` fixá-los.
- `.env` fica fora do git. Só o `.env.example` com placeholders é versionado.
- A chave entra apenas em runtime, via `env_file`. Nunca em `ARG`, `ENV`, camada de imagem, Caso,
  Linha do Tempo, log ou export.

## 3. Build

Use o **builder padrão** do Docker. Com um driver `docker-container` (buildx), a imagem local não
fica visível e o build tenta puxar `docker.iscinternal.com`, que é um registry interno e falha.

```bash
docker buildx use default   # garante o driver docker

docker compose build
```

O `Dockerfile` tem um único `ARG IMAGE` com a tag fixa:

```dockerfile
ARG IMAGE=signalnoir/iris-aihub:2026.3.0AI.154.0
FROM $IMAGE
```

O build instala o IPM em versão pinada e compila o código. O build **nunca** lê a chave. A SPA é
compilada num estágio multi-stage com Node pinado e o estático é copiado para dentro da imagem, num
caminho fora de qualquer bind mount.

## 4. Subir

```bash
docker compose up -d
```

O compose da submissão tem um único serviço `iris`:

- `env_file: .env`;
- `ISC_CPF_MERGE_FILE=/home/irisowner/dev/merge.cpf`;
- portas fixas `1972:1972` (superserver) e `52773:52773` (web);
- healthcheck TCP em `1972`;
- **sem** bind mount do repositório;
- **sem** volume nomeado: os dados vivem na camada gravável do container.

Verificação:

```bash
docker compose ps
docker inspect --format '{{.State.Health.Status}}' \
  "$(docker compose ps -q iris)"

# readiness da aplicação (endpoint definido na spec 001)
curl -fsS http://localhost:52773/signalnoir/api/v1/cases >/dev/null && echo ready
```

## 5. Bootstrap no start

O start roda `%ZSTART` → método de `SignalNoir.Interop`, de forma idempotente:

- materializa Provedor, modelo e chave na configuração do AI Hub
  (Config Store com `RebuildRegistry`; fallback `%AI.Provider.Create`);
- verifica os timeouts;
- garante a Production;
- garante o agendamento do sweeper;
- carrega as fixtures de referência.

Se o Config Store falhar com `ERROR #26414: No descriptor found for AI.LLM / AI.MCP`, rode
`##class(%ConfigStore.DescriptorManager).RebuildRegistry()` ou use o fallback `%AI.Provider.Create`.

## 6. Validar

1. Sem chave: a aplicação sobe, reporta o Provedor como indisponível e os Casos que precisam dele
   terminam em `ReviewRequired` com esse motivo.
2. Com chave: um Pedido sintético percorre o fluxo e o primeiro Caso aparece em até 15 minutos.
3. `docker compose restart` e `docker compose stop` + `start` preservam Casos, Aprovações e Linha do
   Tempo.
4. `docker compose down` recria o estado da demo. O README declara isso.

## 7. Ciclo de vida e durabilidade

| Comando | Efeito |
|---|---|
| `docker compose restart` | Container reinicia; dados preservados. |
| `docker compose stop` + `start` | Container para e volta; dados preservados. |
| `docker compose down` | Container e camada gravável são removidos; estado da demo recriado. |

Não há volume nomeado por decisão da AD-27: o contrato de durabilidade é `restart`/`stop`/`start`.

## 8. Arquiteturas

- x64 e ARM64 usam o tarball correspondente do build 154.
- Os dois retagueiam para `signalnoir/iris-aihub:2026.3.0AI.154.0`.
- Confirme com `docker image inspect signalnoir/iris-aihub:2026.3.0AI.154.0`.

## 9. O que NÃO copiar do template `ai-hub-dev-template`

O template é a referência do build 154, mas parte dele é específica do produto MCP Gateway:

- não copie o serviço `mcp-launcher`;
- não copie variáveis `MCP_*` nem `WG_*`;
- não exponha a porta `8080`;
- não use a URL `docker.iscinternal.com` como origem de pull em runtime;
- não use bind mount `./:/home/irisowner/dev` no compose da submissão;
- não leia segredo no build;
- não use o build 162.

## 10. Troubleshooting

| Sintoma | Causa provável | Ação |
|---|---|---|
| `pull access denied` para `docker.iscinternal.com` | buildx com driver `docker-container` | `docker buildx use default` e refaça o build |
| `No such image` | load ou retag não executado | `docker images`, refaça o retag |
| Healthcheck `unhealthy` | superserver ainda subindo | aguarde `start_period` e veja os logs |
| `ERROR #26414` no Config Store | descriptors do AI Hub | `RebuildRegistry()` ou fallback `%AI.Provider.Create` |
| App sobe mas Casos vão para `ReviewRequired` | chave ausente ou inválida | confira `.env`; o comportamento é o esperado sem chave |
| Build falha ao instalar IPM | versão `latest` removida/instável | use a versão pinada no `Dockerfile` |

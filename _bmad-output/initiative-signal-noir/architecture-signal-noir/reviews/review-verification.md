# Revisão de verificação: decisões checadas contra a realidade

Spine revisado: `../architecture-signal-noir.md` (draft, 2026-10-19). Pesquisa anterior: `../research-stack.md`.
Lente: cada decisão comprometida foi pesquisada na web ou checada contra o projeto ou o starter atual, ou foi afirmada a partir de memória?
Data da checagem: 2026-10-19. Todo conteúdo da web foi tratado como dado.

## Veredito

As versões do front-end e os fatos centrais do AI Hub batem com fontes primárias de hoje. O ponto fraco está no empacotamento. O spine se apoia no `ai-hub-dev-template`, mas o starter que existe neste repositório é o `intersystems-iris-dev-template` antigo, e várias decisões de imagem, de compose e de inicialização não foram confrontadas com ele. Há também dois rótulos desatualizados (Compose "v2" e IPM "latest").

## Conferido e correto

| Afirmação do spine | Resultado | Fonte |
| --- | --- | --- |
| Svelte 5.57.2 | `latest`, publicado em 2026-10-06 | https://registry.npmjs.org/svelte |
| SvelteKit 3.1.0 | `latest`, de 2026-10-14. As peers são `vite ^8.0.12`, `svelte ^5.57.1` e `vite-plugin-svelte ^7`. TypeScript ^6 é peer opcional. Exige `node >=22.17` | https://registry.npmjs.org/@sveltejs/kit |
| adapter-static 4.0.0 | `latest`, de 2026-10-01, com peer `@sveltejs/kit ^3.0.0-next.0` | https://registry.npmjs.org/@sveltejs/adapter-static |
| Vite 8.3.4 | `latest`, de 2026-10-08 | https://registry.npmjs.org/vite |
| Node 24.22.0 LTS | Krypton, publicado em 2026-10-14 | https://nodejs.org/dist/index.json |
| Hash routing (AD-17) | Continua no Kit 3: `kit.router.type: 'pathname' \| 'hash'` | https://github.com/sveltejs/kit/blob/main/packages/kit/src/core/config/options.js |
| Build 154 é o atual | O template oficial fez "Container version bump" para `2026.3.0AI.154.0` em 2026-10-16 | https://github.com/intersystems-community/ai-hub-dev-template (Dockerfile e commits) |
| `%AI.Provider.Create` / `CreateFromConfig` (AD-18) | Existem no SDK Guide atual | https://github.com/intersystems-community/ai-hub-eap/blob/master/ObjectScript_SDK_Guide.md |
| IPM fora da imagem do AI Hub | Confirmado. O `iris.script` do template instala o IPM em tempo de build | https://github.com/intersystems-community/ai-hub-dev-template/blob/master/iris.script |
| `VERSIONPROPERTY` e `%SYS.Task.Definition` | Documentados na doc irislatest (2026.2). A linha 2026.3AI não foi verificada, mas o risco é baixo (são APIs do núcleo) | research-stack.md §3.2–3.3 |

## Achados

### V-1 (alta): o starter local não é o do AI Hub, e o spine não reconciliou os dois

O spine e a pesquisa descrevem o `ai-hub-dev-template`. Os arquivos deste repositório vêm de outro template:
- `Dockerfile`: a cadeia de `ARG IMAGE` termina em `intersystems/iris-community:latest-cd`, e o ZPM é baixado com `wget`.
- `iris.script`: carrega `/tmp/zpm.xml`.
- Testes: usam `%ZPM.PackageManager`.
- `merge.cpf`: tem `SystemMode=IRIS Dev Template`.
- `docker-compose.yml`: não tem `env_file`.

O template do AI Hub faz o contrário: baixa o installer via `%Net.HttpRequest` com `SSLConfiguration="ISC.FeatureTracker.SSL.Config"`, usa `env_file: .env` e define `SystemMode=AI Hub EAP`. Ninguém verificou se a imagem do build 154 tem `wget`, e nada no spine diz qual starter prevalece.

Ação: registrar no Structural Seed que o starter será substituído ou adaptado ao do `ai-hub-dev-template`. Também vale trocar o `wget` pelo padrão `%Net.HttpRequest` e a classe `%ZPM.PackageManager` por `zpm "test ..."`.

Fontes: arquivos locais `/Users/henryhamon/workstation/congenial-waffle/{Dockerfile,iris.script,merge.cpf,docker-compose.yml}`, https://github.com/intersystems-community/ai-hub-dev-template e https://github.com/intersystems/ipm (README, instalação via `%Net.HttpRequest`).

### V-2 (alta): no AD-18, `.env` é um recurso de runtime, e o build da imagem não o enxerga

O AD-18 manda materializar a configuração do AI Hub "na inicialização". No starter, o único passo de setup é o `iris.script`, que roda no `docker build`. O `env_file` do compose só existe com o container em execução, e a issue #31 relata que jobs em background não enxergam o ambiente.

O spine não diz qual gancho de runtime faz essa materialização. Candidatos: `%ZSTART`, `OnStart` da Production, ou um script de entrypoint. Também não diz como o gancho roda de novo quando o jurado troca a chave.

Ação: nomear o gancho e torná-lo idempotente.

Fontes: issue #31 (https://github.com/intersystems-community/ai-hub-eap/issues/31) e o `docker-compose.yml` do template (`env_file: .env`).

### V-3 (média): a Q-C já tem resposta parcial, e o plano B do AD-18 pode ser simplificado

A issue #33 continua aberta. Em 2026-10-14, um comentário relatou que, no build 154 community, o Config Store "quase" funciona: falta rodar `do ##class(%ConfigStore.DescriptorManager).RebuildRegistry()` porque os descriptors não são gerados no start. Um mantenedor respondeu que o próximo kit corrige isso.

Ação: incluir o `RebuildRegistry()` no passo de inicialização e manter `%AI.Provider.Create` como fallback.

Fonte: https://github.com/intersystems-community/ai-hub-eap/issues/33. O comentário é de terceiro e foi tratado como dado. Confirmar no spike.

### V-4 (média): a Q-B tem resposta documental

O SDK Guide atual descreve `max_iterations` como "tool-call rounds per Chat() turn" (o padrão é 10, e 0 remove o limite). Ou seja, as tools rodam dentro de `Chat()`. Isso reforça o AD-15.

Dois pontos ficam para o spike:
- **Orçamento de Ferramentas.** O AD-10 aplica o orçamento por contagem e por tempo na porta. Ele precisa conversar com `max_iterations` da sessão, ou o agente pode esgotar as iterações antes do orçamento ou o inverso.
- **Issue #36 (fechada).** Exceções de tool ficavam escondidas do chamador. É preciso confirmar se a correção está no 154.

Fontes: ObjectScript_SDK_Guide.md (linhas sobre `max_iterations`) e https://github.com/intersystems-community/ai-hub-eap/issues/36.

### V-5 (média): o bind mount do compose apaga o estático copiado no build

O `docker-compose.yml` local monta `./:/home/irisowner/dev`. Se o estágio final copiar a SPA compilada para qualquer caminho dentro de `/home/irisowner/dev`, o volume esconde essa cópia em runtime. Nesse caso, a interface só aparece se `ui/build` existir no host, e isso contradiz "sem runtime Node na submissão".

Ação: copiar o estático para um caminho fora do mount (por exemplo, `/usr/irissys/csp/signalnoir`) ou remover o bind mount do compose do jurado.

Fonte: `docker-compose.yml` local.

### V-6 (média): o multi-stage sobre uma imagem carregada por `docker load` não foi checado (o próprio spine marca [ASSUMPTION])

Com o driver padrão `docker` do BuildKit, um `FROM` aponta para imagens locais. Com um builder `docker-container` (`docker buildx create`), as imagens locais não ficam visíveis. O build então tenta puxar de `docker.iscinternal.com`, que é um registry interno da ISC, e falha.

Os tarballs x64 e arm64 carregam o mesmo nome de tag, então o `ARG IMAGE` funciona nos dois. O `node:24.22.0` é multi-arch.

Ação: documentar no README que o build usa o builder padrão e incluir o retag explícito (`docker tag ... signalnoir/iris-aihub:154`) no passo de instalação.

Fontes: https://docs.docker.com/build/builders/drivers/ (não relido nesta revisão; é conhecimento geral, então confirmar) e o README do ai-hub-dev-template ("Loaded image: docker.iscinternal.com/...").

### V-7 (baixa): "Docker Compose v2" está desatualizado como rótulo

A versão atual é a v5.6.0, de 2026-10-02. O comando `docker compose` (plugin) é o mesmo. Melhor escrever "Docker Compose plugin (`docker compose`), testado com v5.x" e definir uma versão mínima.

Fonte: https://github.com/docker/compose/releases

### V-8 (baixa): "IPM latest" deixa o build sem reprodutibilidade

A última versão estável é a v0.10.10, de 2026-10-14, e já existe uma v0.10.11-beta.1, de 2026-10-16. O installer `latest` pode mudar entre o build do time e o do jurado.

Ação: fixar `/packages/zpm/0.10.10/installer`, que o README do IPM aceita no formato `/packages/zpm/<versão>/installer`.

Fontes: https://github.com/intersystems/ipm/releases e o README do IPM.

### V-9 (baixa): Node 24 sai de Active LTS amanhã

O Node 24 entra em Maintenance LTS em 2026-10-20, e o Node 26 vira LTS em 2026-10-28. Isso deixou de ser "não confirmado" na pesquisa. Para um build só da SPA, o 24 continua aceitável até 2028-04-30. Fixar a tag exata `node:24.22.0` no Dockerfile.

Fonte: https://github.com/nodejs/Release/blob/main/schedule.json

### V-10 (baixa): duas premissas do AD-17 não foram checadas

1. **Web server na imagem.** Desde a 2023.2, os containers IRIS deixaram de trazer o Private Web Server. A Community Edition era a exceção anunciada. O template do AI Hub expõe a porta 52773, o que indica que o portal funciona, mas ninguém confirmou que o web server da imagem 154 serve `ServeFiles` para uma web app customizada.
2. **Sub-caminho no Kit 3.** O SvelteKit 3 removeu `base` e `assets` de `$app/paths`. Uma SPA servida sob um sub-caminho do IRIS (por exemplo `/signalnoir/`) precisa de `kit.paths.base` ou `paths.relative`, e o spine não define o caminho da web app estática nem o mecanismo IPM que a cria (`<CSPApplication>`/`<WebApplication>` no `module.xml`).

Fontes: https://community.intersystems.com/node/532246 e https://community.intersystems.com/node/547061 (descontinuação do PWS), além do CHANGELOG do SvelteKit 3.0.0 (https://github.com/sveltejs/kit/blob/main/packages/kit/CHANGELOG.md).

## Itens sem verificação possível hoje (encaminhar ao spike de 25/10)

- `%AI.Agent` dentro de um BO customizado (Q-A). Não há doc nem exemplo oficial.
- Release notes do build 154. Não encontradas.
- O comportamento real de `ServeFiles` e da web app com sub-caminho na imagem 154.

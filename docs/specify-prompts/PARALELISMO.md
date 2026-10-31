# Paralelismo — Signal Noir

Como dividir as 12 specs entre 3 pessoas sem donos fixos e sem conflito de merge.

## Modelo

- **Sem donos fixos.** Cada spec é reivindicada (claim) por quem estiver livre.
- **Uma spec por pessoa por vez.** Ao terminar, a pessoa pega a próxima spec livre.
- **`001` é serial.** Só ela precisa terminar antes das demais; ela publica `docs/seams.md`.
- **Merge por gate**, nunca por spec isolada.

## Regras

1. `001` roda sozinha até publicar `docs/seams.md` com DTOs, portas e fakes.
2. Antes de começar, marque a spec no board. Ninguém pega uma spec já marcada.
3. Cada spec em worktree própria, com `SPECIFY_FEATURE_DIRECTORY` fixado.
4. Specs com porta ainda não implementada usam os **fakes** do `001`; não esperam a outra spec.
5. Merge só no gate, na ordem de dependência. Arquivos de integração só mudam no gate.
6. Divergência de contrato **não se resolve no merge**: vira uma feature de `contract-change`.
7. Calendar gate: antes de 2026-10-26 só spec, plan, tasks e contratos; nada de código da submissão.

## Pré-requisitos de início

| Spec | Pode iniciar quando |
|---|---|
| 001 runtime-skeleton-and-seams | imediatamente |
| 002 scenario-simulator | contratos disponíveis (dia 1) |
| 003 order-case-lifecycle | `docs/seams.md` v1 |
| 004 validation-and-reference-data | `docs/seams.md` v1 (porta do Validator) |
| 005 operator-console | contratos + fixtures (dia 1) |
| 014 liquid-console-redesign | implementada no `ui/` (tema claro/escuro, tokens, rail, vidro com fallbacks); falta só a checagem do `theme-init.js` na instância IRIS (T036) | Henry | — | branch `master`, sem commit |
| 006 investigation-and-proposal | `001` + DTOs de Case do `003` + `002` |
| 007 approval-and-outbox | `001` + `004`; pode usar fake do Validator |
| 008 execution-and-recovery | `001` + `002`; pode usar fake de Approval/Execution |
| 009 review-dossier-and-resolution | `004` + `006` (ou fake do Proposal) + fixtures de `ReviewRequired` |
| 010 benchmark-and-reference-run | `004` + `006`; execução final depois de `007`/`008` |
| 011 prior-receipt-p9 | `008` e `009` aceitos + contrato de P9 resolvido |
| 012 packaging-and-cross-install | `001` (build existe); validação final depois de todas |

## Ondas (Henrique e Henry; José na onda 5)

José saiu da implementação em 2026-10-24 e volta só na última onda, para a revisão do 010 e a 011 condicional.

| Onda | Henrique | Henry | José | Gate |
|---|---|---|---|---|
| 0 | — | — | 001 (concluída) | G0 |
| 1 | 002 | 003 | — | — |
| 2 | 004 | 006 (usa o fake do Validator) | — | G1 |
| 3 | 007 | 005 | — | G2 |
| 4 | 008 | 009 + baseline de regras do 010 | — | G3 |
| 5 | 010 runner/scoring → execução de referência | 012 | revisão do baseline e do avaliador → 011 (condicional) | G4 |

Ordem obrigatória na onda 5: baseline e avaliador prontos → revisão do José (registra commit e data) → commit único de congelamento (prompt, modelo, baseline, políticas, fixtures, avaliador, variantes reservadas P5Test/P8Test) → execução de referência → relatório com os metadados de independência. A revisão é caminho crítico do G4; a 011 só entra se sobrar tempo depois dela.

As ondas são sugestão de throughput, não donos. Se alguém terminar antes, puxa a próxima spec cujo pré-requisito já esteja satisfeito.

## Gates

| Gate | Specs | Critério |
|---|---|---|
| G0 | 001 | app sobe, health responde, sem chave não quebra, Caso persiste e `docs/seams.md` publicado |
| G1 | 002 + 003 + 004 | Pedido vira Caso com Proposta validada |
| G2 | 005 + 006 + 007 | Operador vê e aprova uma Proposta real (primeiro ponta a ponta) |
| G3 | 008 + 009 | Execução, P3, recuperação e Dossiê |
| G4 | 010 + 011 + 012 | Benchmark, execução de referência e entrega |

## Arquivos de integração

Nenhuma spec edita estes arquivos durante o desenvolvimento:

- `module.xml`
- `docker-compose*.yml`
- `.github/workflows/**`
- `README.md`

Mudanças neles são aplicadas em lote no gate de integração. Exceção: a 012 é dona do empacotamento e reescreveu o `Dockerfile`, o `docker-compose.yml`, o `README.md` e os workflows (branch `g1-wiring-and-012`).

## Board de claim

| Spec | Status | Pessoa | Onda | Worktree |
|---|---|---|---|---|
| 001 runtime-skeleton-and-seams | concluída | José | 0 | |
| 002 scenario-simulator | implementada (aguardando gate G1; assumida do Henrique em 28/10; V1–V6 verificados no build 154; inclui o leitor do feed da Origem) | Henry | 1 | no `master` (PR #16) |
| 003 order-case-lifecycle | implementada (aguardando gate G1) | Henry | 1 | no `master` |
| 004 validation-and-reference-data | implementada (aguardando gate G1; Validator v2 com o pipeline completo, dados de referência versionados e fixáveis, `Admit`, `Revalidate` e confirmação de recibo anterior; mock e fixtures regenerados, 13 de 13 vereditos conferem; verificada ao vivo por `Tests.Gates.TestGateG1`; o que resta para 007/008/010 está em `specs/004-validation-and-reference-data/contracts/g1-integration.md`) | Henrique | 2 | no `master` (PR #22 e #23) |
| 005 operator-console | implementada (aguardando gate G2; decisão/resolução testadas contra fixtures até 007/009) | Henry | 3 | no `master` |
| 006 investigation-and-proposal | implementada (aguardando gate G2; AI Hub ao vivo verificado, T060; SC-004 medido com gêmeos idênticos, T061) | Henry | 2 | no `master` |
| 007 approval-and-outbox | implementada (aguardando gate G2; assumida do Henrique em 28/10; política de Aprovação padrão até a 004, handler do `Execute` na 008, sweeper ligado no Bootstrap no gate) | Henry | 3 | no `master` (PR #14) |
| 008 execution-and-recovery | implementada (aguardando gate G3; assumida do Henrique em 28/10; política de execução padrão até a 004, mapeamento só com o catálogo da 004) | Henry | 4 | no `master` (PR #17) |
| 009 review-dossier-and-resolution | implementada (aguardando gate G3; Validador v1 até a 004; correção 009b no `master`; integração 008+009 verificada em 29/10 por `Tests.Recovery.TestGateG3`, 5/5, com um caso ao vivo) | Henry | 4 | no `master` |
| 010 benchmark-and-reference-run | reservada | Henrique | 5 | |
| 011 prior-receipt-p9 | condicional | José | 5 | |
| 012 packaging-and-cross-install | parcial (29/10): imagem, compose, README, `.env.example`, smoke, scan de segredos e CI no repositório, verificados no ARM64; faltam a validação rápida (depende da 010), o cross-install do Henrique, o vídeo e a submissão | Henry | 5 | branch `g1-wiring-and-012` |

Trilhas (002, 007 e 008 passaram para o Henry em 28/10): Henrique = validação e benchmark (004 → 010) e integrador dos gates; Henry = Simulador, Caso, Agente, efeito e console (003 → 006 → 005 → 009 → 007 → 002 → 008 → 012); José = revisão do 010 e 011 condicional, só na onda 5.

Papéis fixos fora do board:

- **010 independência (Princípio VIII):** casos reservados e gabarito P5/P8b com Henrique; baseline de regras com Henry (escrito na onda 4); revisão do baseline e do avaliador com José. Henry (autor do Agente) não acessa as variantes reservadas até o congelamento. A revisão do José confirma que o baseline não foi enfraquecido e fica registrada no relatório.
- **012 cross-install:** Henry escreve o README; Henrique instala em máquina limpa.
- **011:** condicional. O José abre o `contract-change` de P9 na onda 5; sem contrato aprovado, ou sem tempo depois da revisão do 010, a 011 fica fora da submissão. Os dados de P9 já existem no Simulador (002, US7).

Lacunas sem dono (registradas em 2026-10-26, resolvidas em 2026-10-28):

- **Leitor do feed da Origem.** Resolvida: `SignalNoir.Interop.Service.OriginFeed.Poll()` (Henry, entregue com a 002) lê `GET /origin/feed`, chama `OrderIn.Accept`, faz a primeira entrega ao Parceiro e reporta a Exceção que abre o Caso. O agendamento fica para o gate G1 (`specs/002-scenario-simulator/contracts/g1-integration.md`).
- **Ambiente com iris-agentic-dev.** Resolvida: V1–V6 verificados no AI Hub build 154 (`specs/002-scenario-simulator/research.md`). Kit em `dev/aihub/README.md`.

Pendências do gate G1 (aplicadas pelo Henry em 2026-10-29, branch `g1-wiring-and-012`):

- Feito: `Sim.Setup.EnsureWebApplication()` no hook de start `boot/%ZSTART.mac` (`/sim/api/v1`), ao lado do Bootstrap e não dentro dele, para manter a fronteira produto↔Simulador (`TestNoCrossReference`).
- Feito: `OriginFeed.Poll()` agendado a cada minuto (`Tasks.OriginFeedTask`).
- Feito: sweeper (`Tasks.SweeperTask`) agendado pelo Bootstrap só com `SN_BACKGROUND_TASKS=1`. O banco de dev fica sem a variável, porque guarda requisições de teste (007 R6).
- Feito: `.env.example` com `SN_SIM_BASE_URL` e `SN_BACKGROUND_TASKS`.
- Feito: a 004 (Proposta validada), PR #22 e #23. O cenário do gate roda ao vivo em `Tests.Gates.TestGateG1`: Pedido do Simulador, aceite, primeira entrega ao Parceiro (a resposta real abre o Caso), investigação com as ferramentas reais, Proposta, veredito v2 com as versões dos dados de referência e Caso em `PendingApproval`. O Caso é roteado para o proposer de regras, como um BenchmarkRun faria (010); sem BenchmarkRun, um Caso novo é do Agente e depende de provedor.
- Aberto, não bloqueia o G1 (onda 4 do Henry): o baseline de regras ainda compara o tipo de espécime sem os sinônimos. Com um Pedido escrito `soro` ele pede revisão, e o Validator aceitaria o mapeamento de soro. A correção é o `Proposers/Rules` chamar `Core.Conditions.Matches`.
- Aberto para a 010: gravar as versões de política e de mapeamento que um BenchmarkRun fixa. O Store já as respeita (`Store.For(run)`); `ResolutionValidator.RunFor` devolve `null` até a execução gravá-las.
- Aberto para a 008 (Henry): `ResolutionValidator.InputFor` passa `attemptCount = 0`. Quando a 008 gravar as Tentativas, é ali que o `RETRY_BUDGET_EXHAUSTED` passa a valer nos Casos reais.

## Merge

- Ordem dentro do gate: dependências primeiro (`002` → `003` → `006`, etc.).
- A zona de escrita de cada spec é contrato. Conflito em arquivo compartilhado é violação de zona: pare e negocie, não force o merge.
- Contrato divergente: abra `contract-change`, ajuste contrato + fixtures, rode o validador, depois retome.
- Gate verde só quando o cenário observável funciona ponta a ponta e nenhum teste falha.

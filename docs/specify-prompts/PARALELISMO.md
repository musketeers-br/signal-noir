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

Mudanças neles são aplicadas em lote no gate de integração.

## Board de claim

| Spec | Status | Pessoa | Onda | Worktree |
|---|---|---|---|---|
| 001 runtime-skeleton-and-seams | concluída | José | 0 | |
| 002 scenario-simulator | spec/plan/tasks prontos | Henrique | 1 | `.claude/worktrees/002-scenario-simulator` |
| 003 order-case-lifecycle | implementada (aguardando gate G1) | Henry | 1 | branch `003-order-case-lifecycle` |
| 004 validation-and-reference-data | reservada | Henrique | 2 | |
| 005 operator-console | reservada | Henry | 3 | |
| 006 investigation-and-proposal | implementada (aguardando gate G2; AI Hub ao vivo pendente, T060) | Henry | 2 | branch `006-investigation-and-proposal` |
| 007 approval-and-outbox | reservada | Henrique | 3 | |
| 008 execution-and-recovery | reservada | Henrique | 4 | |
| 009 review-dossier-and-resolution | reservada | Henry | 4 | |
| 010 benchmark-and-reference-run | reservada | Henrique | 5 | |
| 011 prior-receipt-p9 | condicional | José | 5 | |
| 012 packaging-and-cross-install | reservada | Henry | 5 | |

Trilhas: Henrique = Simulador e efeito (002 → 004 → 007 → 008 → 010) e integrador dos gates; Henry = Caso, Agente e console (003 → 006 → 005 → 009 → 012); José = revisão do 010 e 011 condicional, só na onda 5.

Papéis fixos fora do board:

- **010 independência (Princípio VIII):** casos reservados e gabarito P5/P8b com Henrique; baseline de regras com Henry (escrito na onda 4); revisão do baseline e do avaliador com José. Henry (autor do Agente) não acessa as variantes reservadas até o congelamento. A revisão do José confirma que o baseline não foi enfraquecido e fica registrada no relatório.
- **012 cross-install:** Henry escreve o README; Henrique instala em máquina limpa.
- **011:** condicional. O José abre o `contract-change` de P9 na onda 5; sem contrato aprovado, ou sem tempo depois da revisão do 010, a 011 fica fora da submissão. Os dados de P9 já existem no Simulador (002, US7).

## Merge

- Ordem dentro do gate: dependências primeiro (`002` → `003` → `006`, etc.).
- A zona de escrita de cada spec é contrato. Conflito em arquivo compartilhado é violação de zona: pare e negocie, não force o merge.
- Contrato divergente: abra `contract-change`, ajuste contrato + fixtures, rode o validador, depois retome.
- Gate verde só quando o cenário observável funciona ponta a ponta e nenhum teste falha.

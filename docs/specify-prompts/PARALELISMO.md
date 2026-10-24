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

## Ondas para 3 pessoas

| Onda | Pessoa A | Pessoa B | Pessoa C |
|---|---|---|---|
| 0 | 001 | 002 | 005 |
| 1 | 003 | 004 | 012 |
| 2 | 006 | 007 | 009 |
| 3 | 008 | 010 | 011 (se aprovado) |
| Fechamento | 012 validação final | — | — |

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
| 002 scenario-simulator | reservada | Henrique | 1 | |
| 003 order-case-lifecycle | reservada | Henry | 1 | |
| 004 validation-and-reference-data | reservada | José | 1 | |
| 005 operator-console | reservada | Henrique | 2 | |
| 006 investigation-and-proposal | reservada | Henry | 2 | |
| 007 approval-and-outbox | reservada | José | 2 | |
| 008 execution-and-recovery | reservada | José | 3 | |
| 009 review-dossier-and-resolution | reservada | Henry | 3 | |
| 010 benchmark-and-reference-run | reservada | Henrique | 3–4 | |
| 011 prior-receipt-p9 | condicional | José | 4 | |
| 012 packaging-and-cross-install | reservada | Henry | 4 | |

Trilhas: José = efeito (004 → 007 → 008 → 011); Henry = Caso/Agente (003 → 006 → 009 → 012); Henrique = borda e integração (002 → 005 → 010) e integrador dos gates.

Papéis fixos fora do board:

- **010 independência:** casos reservados e gabarito P5/P8b com Henrique; baseline de regras com José; revisão do baseline e do avaliador com Henry. Henry (autor do Agente) não acessa o conjunto de teste reservado.
- **012 cross-install:** Henry escreve o README; Henrique instala em máquina limpa. Se 011 não for aprovado, José reforça cross-install e vídeo.
- **011:** José abre o `contract-change` de P9 ainda na fase de spec.

## Merge

- Ordem dentro do gate: dependências primeiro (`002` → `003` → `006`, etc.).
- A zona de escrita de cada spec é contrato. Conflito em arquivo compartilhado é violação de zona: pare e negocie, não force o merge.
- Contrato divergente: abra `contract-change`, ajuste contrato + fixtures, rode o validador, depois retome.
- Gate verde só quando o cenário observável funciona ponta a ponta e nenhum teste falha.

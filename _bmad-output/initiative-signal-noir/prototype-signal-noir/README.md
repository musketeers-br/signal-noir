# Protótipo do Signal Noir

Protótipo **descartável** da interface do Operador, feito para o time ter uma noção concreta da solução final antes de B03 congelar o contrato de UX. Épico: `../tickets/epic-prototipo-solucao/epic-prototipo-solucao.md`.

> **Não é código da submissão.** Não copie nada daqui para `ui/`, para a imagem nem para o compose (R38). Todos os dados são sintéticos, e as métricas são ilustrativas.

## Como abrir

Dê um duplo clique em `index.html`. Ele abre por `file://`, sem servidor, build ou internet, num navegador atual (Chrome, Edge ou Firefox).

- **Scenarios** (botão no topo) abre o painel que dirige o servidor simulado. Em telas largas, o painel já começa aberto.
- **You are** guarda o nome declarado do Operador. Não há autenticação.
- **API log** mostra cada chamada à API simulada (`/signalnoir/api/v1`), com request e response. Marque "include polling GETs" para ver também o polling.

O relógio é virtual: começa em 29/10/2026, 10:00 BRT, e anda 1 s por segundo real. **Reset the whole prototype** volta tudo ao início.

## Roteiro de revisão (cerca de 10 min)

| # | Cenário no painel | O que observar | Requisito do épico |
|---|---|---|---|
| 1 | *A lying 500 and two approved mappings* (já roda ao abrir) | Caso em camadas, Evidência separada de Diagnóstico, conflito lado a lado. Aprovar mostra o diff exato `GLIC-J → GLIC-S`. Depois de aprovar, use "Send the same approval again": a resposta é 200 `idempotentReplay`, sem nova execução. | R8, R9, R12, R13 |
| 2 | *The proposal changes while you review it* | Abra "Review & approve…" e espere uns 5 s antes de aprovar: a resposta é 409 `STALE_VERSION`, nada é aprovado, e o botão leva à versão nova. | R14 |
| 3 | *The partner degrades after approval* | Aprovar, a Revalidação falha e o Caso vai para `Held` sem envio. As reavaliações aparecem na Linha do Tempo. Depois sai uma nova Proposta, que exige nova Aprovação. | R15 |
| 4 | *The order is cancelled at the origin after approval* | Aprovar, a Revalidação falha e o Caso termina `Cancelled`, sem envio. | R15 |
| 5 | *The partner accepts but the response is lost* | Banner violeta "Outcome unknown". "Try to send again with a new proposal" é bloqueado (`CommandDiscarded`). A Reconciliação encontra o Recibo, sem reenvio. | R16 |
| 6 | *The LLM provider is unavailable* (já aberto) | O Dossiê separa "What was checked" de "What we don't know". Resolver com `map_glicj_soro` dá 422 do validador; `map_glicj_plasma` resolve. | R10, R17 |
| 7 | *Ambiguous patient identity* (já aberto) | Registros em colisão com os campos divergentes marcados. `RETRY` é bloqueado (`IDENTITY_AMBIGUOUS_NO_AUTOMATIC_ACTION`); `HOLD` e `Cancel` são aceitos. | R10 |
| 8 | *The "failed" order was already delivered* (P9, condicionado) | `ResolvedByPriorReceipt` sem nenhuma Execução. | R18 |
| 9 | Aba **Benchmark** | Relatório em duas partes, com um empate visível. Os números são de layout, não medidos. | R11 |

Depois da revisão, registre tudo em `findings.md`.

## Estrutura

| Arquivo | Papel |
|---|---|
| `index.html` | Casca da página, diálogo de Aprovação, painel e log. |
| `styles.css` | Tokens provisórios, tema claro e escuro, layout de 360 px a desktop. O DESIGN.md real sai de `bmad-ux`. |
| `fixtures.js` | Dados de referência (mapeamentos, catálogo de Ações) e roteiros dos cenários. Os nomes de campos seguem `contracts/openapi-signalnoir.yaml`. |
| `engine.js` | API simulada (`listCases`, `getCase`, `getTimeline`, `decide`, `resolve`) com as regras do contrato: 400, 409 `STALE_VERSION` e `INVALID_TRANSITION`, 200 `idempotentReplay` e 422 do validador. Inclui o motor determinístico dos roteiros. Não usa DOM. |
| `app.js` | Interface com roteamento por hash e polling de 1,5 s, como no AD-17. Só fala com a API simulada. |
| `tests/engine.test.js` | Teste do motor sem navegador: `node tests/engine.test.js .` |
| `tools/export-api-fixtures.js` | Gera as fixtures da API em `contracts/fixtures/` a partir dos cenários. Elas são validadas contra o contrato por `contracts/tools/validate_fixtures.py`. |
| `findings.md` | Aprendizados e propostas de mudança de contrato para B03. |

## Verificação feita em 20/10

- `tests/engine.test.js`: todos os cenários chegam ao estado final esperado. Também cobre 400, 409, 422, 200 de replay, uma única execução por efeito, `seq` da Linha do Tempo contínuo, cadeia de estados consistente e nenhum campo interno vazando pela API.
- Chrome headless, dirigido via DevTools Protocol: 19 verificações de interface nos fluxos 1 a 7, mais Benchmark e 390 px. Sem erros de console e sem rolagem horizontal em 390 px.

## Limites conhecidos

- Não há backend, persistência, autenticação nem chamadas de rede. "Restart the Production now" só registra um evento.
- O link do Visual Trace é simulado.
- O protótipo segue o contrato `1.0.0-draft.2` (PR #2): `dossier.unknowns`, `executionOutcome` na lista e `leaseGeneration`.
- O tema escuro segue a preferência do sistema.

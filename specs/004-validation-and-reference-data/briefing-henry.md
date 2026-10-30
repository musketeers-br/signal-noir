# 004 → Henry: seis edições em arquivos da 003/006/009

**De:** Henrique · **Spec:** 004 validation-and-reference-data · **Detalhe:** `contracts/coordination-004-006-009.md`

## O que preciso de você

Concordar (ou ajustar) as 6 edições abaixo. São pequenas, em arquivos que você já fez merge. Sem o seu ok, eu não toco neles. Isso bloqueia as tarefas T003, T005 (veredito v2), T006, T009 e T010, e com elas toda a US1 (T016–T020), que é o caminho crítico dos gates G1/G2/G3.

Nenhuma edição muda `contracts/openapi-signalnoir.yaml`.

## Já pronto, sem tocar em nada seu

DTOs `ValidationInput`, `PreconditionResult`, `Admission`, `ReferenceData`; tabela `Core.Reasons` (32 códigos); dados de referência 2026.10.1 (política e mapeamentos); `Reference.Store` com carga tudo-ou-nada, versão em vigor e versões fixadas por Run. Testes: 26 novos, verdes. Suíte completa: 291 passam, 9 falham. As 9 falham igual no `master`, por falta de provedor de IA (o Caso novo vai para `ReviewRequired`).

## As 6 edições

| # | Arquivo | Mudança | Tarefa |
|---|---------|---------|--------|
| 1 | `Application/ResolutionValidator.cls` | `Verdict(validator, proposal, now)` passa a `Verdict(validator, input)`. Novo `InputFor(rec, proposal, now)` monta o Validation Input. Devolve o veredito do contrato, com `versions`. | T015→T019 |
| 2 | `Application/CaseService.cls` | `CompleteInvestigation` e `ResolveReview` chamam `InputFor`. O payload do evento `ValidatorVerdict` ganha `versions`. | T015 |
| 3 | `Core/ActionCatalog.cls` | `Entries()` preenche `requiredEvidence` (hoje `[]`). **`RequiresApproval` já devolve `ExternalEffect(action)` no `master`**, então `REQUEST_REVIEW` já é `false`. Falta só o `requiredEvidence`. | T010 |
| 4 | `Tools/LocalSource.cls` | `tool.policies` e `tool.mapping_catalog` respondem pelo Store, no lugar de "reference data not loaded". Ausente quando nada está carregado. | T037 |
| 5 | `Api/Dispatch.cls` | `Mappings()` serve o Store, no lugar do placeholder `"unloaded"`. | T037 |
| 6 | `FakeValidator`, `Consumer`, `TestConsumerUsesSeam`, `TestResolution`, `TestDossier` | Formato v2: `accepted`/`blocked` no lugar de `valid`/`invalid`. | T003, T006 |

**Ordem sugerida:** 6 primeiro (só testes e fakes), depois 3, depois 1 e 2 juntas, depois 4 e 5 (essas só na US2+).

## Dois pedidos para o baseline do seu lado (onda 4)

1. **Rules e sinônimos de specimen.** `Proposers/Rules` compara `specimen.type` com `$ZConvert(...,"U")`. Um Order com `soro` não casa com o mapeamento `SERUM`, mas o Validator aceitaria. Pedido: chamar `Core.Conditions.Matches(conditions, order, result.synonyms)` (entrega da 004, US2), para Rules e Validator concordarem.
2. **`requiresApproval` de `REQUEST_REVIEW`.** O endpoint `GET /reference/action-catalog` e o veredito têm que reportar o mesmo valor. Hoje isso já vale no `master`. Só peço que o teste do seu lado fixe isso.

## Para decidir na conversa

- [ ] Edições 1–6 aprovadas como estão
- [ ] Ajustes pedidos: ______________________
- [ ] Pedidos 1 e 2 aceitos para o baseline
- [ ] T045 da spec 001 (segundo membro aprova a mudança de contrato 001): aprovado

Registro a decisão no fim de `contracts/coordination-004-006-009.md`.

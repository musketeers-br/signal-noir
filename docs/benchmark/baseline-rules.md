# Baseline de regras do benchmark (`rules-v2`)

- **Spec:** [`specs/010-benchmark-and-reference-run/spec.md`](../../specs/010-benchmark-and-reference-run/spec.md), FR-012 e FR-013 (T053)
- **Código:** [`src/SignalNoir/Proposers/Rules.cls`](../../src/SignalNoir/Proposers/Rules.cls), `Parameter VERSION = "rules-v2"`
- **Autor:** Henry. **Revisão:** José (T055), registrada em `Benchmark.Data.Reviews`.
- **Independência:** o autor deste baseline não leu as variantes reservadas de teste (`P5Test`, `P8Test`) nem
  os gabaritos de teste antes do congelamento (05/11/2026). As regras abaixo foram escritas a partir do
  catálogo de ações, do conjunto de Mappings `2026.10.1` e das variantes de *tuning*.

## O que o baseline é

O modo `rules` é um proposer determinístico que passa pelo mesmo caminho do Agent: a mesma Evidence, o mesmo
gateway de ferramentas, o mesmo orçamento e o mesmo Validator (Constitution VIII). Ele lê só o pacote base de
Evidence e não faz chamadas extras. Não lê texto livre como instrução e não infere causa a partir do corpo da
resposta do Partner. Quando nenhuma regra identifica uma ação segura, pede revisão humana.

Toda Proposal das Rules passa pelo Validator como qualquer outra. Uma regra nunca dispensa aprovação.

## Regras, em ordem

A primeira regra que se aplica decide.

| # | Condição (sobre a Evidence) | Ação | Confiança | Evidence citada |
|---|---|---|---|---|
| 1 | `Core.Identity.Collisions` acha registros de paciente que colidem com o paciente do Order (`tool.receipts_and_orders_by_patient`) | `REQUEST_REVIEW` (`reason: ambiguous identity`) | LOW | receipts |
| 2 | `tool.partner_health` diz `DOWN`, **ou** `tool.partner_failure_history` mostra `timeouts / total >= 0.5` numa janela com `total > 0` | `HOLD` (`reason: partner unstable`), pré-condição `PARTNER_HEALTHY_WINDOW = false` | MEDIUM | health e/ou history |
| 3 | Exatamente **um** Mapping aprovado de `tool.mapping_catalog` se aplica ao Order: o `sourceCode` é um dos códigos de exame (trim, sem distinção de caixa) e **todas** as condições casam com `Core.Conditions.Matches`, usando os `synonyms` do catálogo | `APPLY_APPROVED_MAPPING` com `mappingId` e `mappingVersion`, pré-condição `MAPPING_VERSION_UNCHANGED` | MEDIUM | catálogo e `system.exception` |
| 4 | Nenhuma das anteriores | `REQUEST_REVIEW` (`reason: no rule applies`) | LOW | `system.exception` |

### Detalhes da regra 2

A janela de `tool.partner_failure_history` contém só as tentativas **deste Order** no cenário: o Simulator
filtra por `scenarioInstanceId` e `orderId`. Um erro respondido (4xx, ou 500 com corpo) é a própria falha sob
investigação e não indica instabilidade, por isso a regra conta só timeouts. Em `rules-v1` ela contava
qualquer erro: a primeira falha já dava `errorRate = 1`, e todo Case P5 ou P8b ao vivo terminava em `HOLD`
antes de a regra 3 rodar.

### Detalhes da regra 3

- A comparação é a mesma do Validator (`MAPPING_CONDITION_MATCHES`). Valores são comparados depois de trim,
  caixa alta e da lista de sinônimos: com `{"specimenType": {"SERUM": ["SERUM", "SORO"]}}`, um Order escrito
  `soro` acha o Mapping de `SERUM`. Por isso Rules e Validator não podem discordar sobre um Mapping.
- Uma condição sobre um campo que o Order não tem nunca casa. Um Mapping sem condições casa com qualquer
  Order que tenha o código de exame.
- Se o catálogo vier sem `synonyms`, a comparação é exata, sem palpite.
- Zero candidatos ou dois ou mais candidatos: a regra não decide e cai na regra 4. O baseline nunca escolhe
  entre Mappings.

## Por família

O comportamento abaixo vem das regras, não de um gabarito. Ele vale para as variantes de *tuning*; as de
teste não foram lidas.

### P5: o Partner mente sobre a causa

Um 500 cujo corpo é um erro de validação de negócio, ou um 200 com rejeição em texto livre. `P5.injection`
acrescenta uma instrução embutida no corpo e na nota do Order.

- O baseline não lê o corpo nem a nota como instrução. A instrução embutida não muda nada nas regras.
- Com o Partner estável, a decisão vem da regra 3: o Order `GLIC-J` com amostra `soro` ou `SERUM` acha só
  `map_glicj_soro` e as Rules propõem `APPLY_APPROVED_MAPPING map_glicj_soro`.
- Com amostra que nenhum Mapping cobre, ou com dois candidatos, a saída é `REQUEST_REVIEW`.
- O 500 ou o 200 com rejeição é uma resposta, não um timeout, então a regra 2 não segura o Case. Um 500 de
  instabilidade real com health `UP` e sem timeouts também chega à regra 3; esse é um limite conhecido, e o
  Validator ainda confere o Mapping proposto.

### P8b: dois Mappings para um código descontinuado

Dois Mappings aprovados para `GLIC-J`, distinguidos só pelo tipo de amostra.

- `plasma` (qualquer caixa) → `APPLY_APPROVED_MAPPING map_glicj_plasma`.
- `soro` ou `SERUM` → `APPLY_APPROVED_MAPPING map_glicj_soro`. Era aqui que `rules-v1` pedia revisão.
- Tipo de amostra ausente, desconhecido ou sem sinônimo → `REQUEST_REVIEW`.

### Fora das famílias centrais

- **P8a** (health `UP`, toda entrega dá timeout): regra 2, `HOLD`, pelos timeouts na janela do Order.
- **Controles `clean`**, por subtipo:
  - `clean.success`: a entrega é aceita, sem falha a investigar.
  - `clean.partner_unavailable` (health `DOWN`): regra 2, `HOLD`.
  - `clean.unknown_code_single_mapping` (`HBA1C-L`, um Mapping sem condições): regra 3,
    `APPLY_APPROVED_MAPPING map_hba1c_legacy`.
  - `clean.ambiguous_identity`: regra 1, `REQUEST_REVIEW`, quando os registros de paciente colidem.
  - `clean.already_processed` (`TSH`, sem Mapping): o baseline não tem regra de recibo anterior e cai na
    regra 4, `REQUEST_REVIEW`.
- **P9** (reenvio de um Order já recebido): mesma situação, sem regra própria; regra 1 se houver colisão de
  identidade, senão regra 4.

## Histórico de versões

| Versão | Mudança |
|---|---|
| `rules-v1` | Regras 1 a 4; a regra 3 comparava só o tipo de amostra, sem sinônimos (o Order `soro` pedia revisão). |
| `rules-v2` | A regra 2 conta só timeouts na janela do Order. A regra 3 usa `Core.Conditions.Matches` com os `synonyms` do catálogo (via `Core.MappingMatch.Candidates`), a mesma comparação do Validator, e confere todas as condições do Mapping. O proposer Decisions continua sem sinônimos. |

## Testes

- `SignalNoir.Tests.Application.TestRulesBaseline`: `soro` acha o Mapping de soro, `plasma` o de plasma,
  amostra desconhecida e catálogo sem sinônimos pedem revisão; o erro do próprio Order não segura o Case,
  timeouts seguram.
- `SignalNoir.Tests.Core.TestMappingMatch`: `Candidates` com e sem sinônimos.
- `SignalNoir.Tests.Gates.TestGateG1`, os dois casos ao vivo contra o Simulator: o Order `plasma` e o Order
  `soro` terminam em `PendingApproval`, com o Mapping certo aceito pelo Validator.
- `requiresApproval` de `REQUEST_REVIEW`: já fixado em `TestReferenceEndpoints`.

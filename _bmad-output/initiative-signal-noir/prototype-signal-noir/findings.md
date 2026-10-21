# Aprendizados do protótipo

Épico: `epic-prototipo-solucao` (R23, R24). Destino: B03 (contrato HTTP e UX), B01 (domínio) e B07/B10 (interface e Dossiê).

## 1. Propostas de mudança de contrato (encontradas na construção, 20/10)

Cada item é uma proposta para B03. Nenhum foi aplicado a `contracts/` (R37).

| ID | Lacuna | Onde apareceu | Proposta | Requisito |
|---|---|---|---|---|
| F-1 | `Dossier` não tem onde dizer **o que não se sabe**. Sem isso, a interface não separa ausência de informação de conclusão negativa. | Dossiê de provider down e de identidade ambígua | Adicionar `Dossier.unknowns: string[]`, preenchido só com lacunas factuais (nunca inferência). | R30 |
| F-2 | `CaseSummary` não indica **resultado incerto**. A lista mostra `Executing` igual para "enviando" e para "pode ter sido entregue". | Lista durante a perda de resposta | Adicionar `CaseSummary.executionOutcome` (`in_progress`, `reconciling`…) ou `uncertain: boolean`. | R34 |
| F-3 | `Execution` só tem `idempotencyKey`. O caderno (ADR-04) exige `commandId`, `executionId` e `businessEffectKey`, além de lease com geração. | Detalhe da Execução | Em B01, renomear ou acrescentar `businessEffectKey` e `leaseGeneration`, e alinhar com o AD-21 e `openapi-sim.yaml`. | R24, R28 |
| F-4 | Não existe forma explícita de **encerrar por Recibo anterior**. O protótipo usa `REQUEST_REVIEW` com `priorReceiptCandidate` e veredito `prior_receipt_confirmed`, o que é ambíguo. | P9 | B01 decide: Ação própria fora do catálogo de efeitos, ou proposta sem Ação. | R4 |
| F-5 | `Evidence` não tem resumo legível. A interface renderiza `result` bruto de forma genérica, o que funciona mas é denso. | Camada de Evidências | Campo opcional `Evidence.summary`, gerado de forma determinística pela Ferramenta, nunca pelo LLM. | R34 |
| F-6 | `ValidatorVerdict.reasons` é texto livre. A interface precisa de um texto por motivo (`MAPPING_CONDITION_MISMATCH`, `IDENTITY_UNRESOLVED`…). | 422 da resolução | Enum fechado de motivos no contrato, com um texto curto por motivo na interface. | R18, R33 |
| F-7 | Não há nome de exibição do Parceiro, só `partnerId`. | Lista e detalhe | `/reference/partners` ou um campo `partnerName` em `CaseHeader`. | R32 |
| F-8 | O diff da Aprovação depende de `/reference/mappings` (`sourceCode` → `targetCode`), porque `order.transformed` só existe depois da execução. | Diálogo de Aprovação | Manter, ou expor `proposal.previewPayload` para a Aprovação mostrar o efeito exato sem montar o diff no cliente. | R21, R33 |
| F-9 | O protótipo usava inicialmente `from`, `to` e `condition` nos mapeamentos, sem perceber que o contrato diz `sourceCode`, `targetCode` e `conditions`. | Fixtures | Já corrigido. Lição: B03 deve gerar as fixtures a partir do OpenAPI. | R37 |

## 2. Observações de UX (Henrique)

- O banner de estado no topo, com texto próprio para cada situação (aguardando você, em espera, resultado desconhecido, revisão), resolveu a exigência de mensagens distintas melhor do que só o chip de estado.
- Rótulos `FACT` e `INTERPRETATION`, com a borda tracejada no Diagnóstico, deixam clara a separação, e os chips de Evidência dentro das afirmações dão a navegação pedida.
- O 409 `STALE_VERSION` precisa manter o diálogo aberto com a explicação. Fechar e mostrar um toast seria fácil de ignorar.
- O painel de cenários e o log da API são ferramentas de revisão. Não entram no produto.
- *(completar durante a revisão)*

## 3. Revisão com Henry e José (até 24/10)

| Pergunta | Henry | José |
|---|---|---|
| O detalhe em camadas torna a Proposta verificável em menos de 1 min? | | |
| A tela de Aprovação deixa claro o efeito exato? | | |
| Espera, revisão e incerteza são distinguíveis sem ler a documentação? | | |
| O Dossiê é útil quando o LLM falha? | | |
| F-1 a F-8: aceitar, ajustar ou recusar? | | |
| O protótipo serve de rascunho para o roteiro do vídeo? | | |

Outras notas:

## 4. Decisão sobre o protótipo (R24)

- [ ] Descartar após a revisão.
- [ ] Manter como referência visual, fora da submissão (e retirar do repositório se o esclarecimento de Q-1 exigir).

Registrar a decisão no memlog da iniciativa: `uv run _bmad/scripts/memlog.py append --workspace _bmad-output/initiative-signal-noir --type decision --text "..."`.

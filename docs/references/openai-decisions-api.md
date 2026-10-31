# Referência: OpenAI Decisions API

- **Fonte:** <https://developers.openai.com/api/docs/guides/decisions>
- **Obtido em:** 2026-10-29
- **Status:** referência externa. Não é contrato deste projeto nem dependência.

> **Atenção:** este resumo foi gerado a partir da página por um modelo auxiliar, não copiado
> literalmente. Confira nomes de campos, modelo (`gpt-6-luna`) e limites contra a página original
> antes de usar qualquer um deles em código ou contrato.

## O que é

Endpoint `POST /v1/decisions`. Avalia texto, imagens e JSON e devolve respostas **tipadas**, em vez
de texto livre. Segundo a página, é cerca de 10x mais rápido que a Responses API para esse tipo de
resposta.

Requisição: `model`, `input` (evidência compartilhada) e `questions` (de 1 a 400).

| Tipo | Resposta |
|---|---|
| `predicate` | `probability` (0 a 1) de uma condição |
| `choice` | uma opção fixa, com `probabilities` e `confidence` |
| `score` | média ponderada por probabilidade de 2 a 10 níveis ordenados, com `confidence` |

Cada resposta traz o `name` da pergunta, que deve ser único. Existe também `refusal`.

Outros pontos: cache de prefixo (mínimo de 1.024 tokens, `prompt_cache_key`), uso em
`GET /v1/organization/usage/decisions`, ZDR e HIPAA para clientes elegíveis, entradas em texto,
mensagens com chamadas de ferramenta, JSON (`input_json`) e imagens base64 ou URL pública.

## O que o guia **não** cobre

- Aprovação humana. Recomenda apenas encaminhar o fallback (`other`) para revisão.
- Idempotência de efeitos.
- Execução de ações. A API só devolve respostas; a aplicação decide e age.

Esses três pontos são exatamente o que o Signal Noir já resolve (Validador, Aprovação, Outbox com
chave de efeito e reconciliação). A API serviria como **fonte de propostas**, não como substituta
do resto.

## Encaixe no Signal Noir

- O lugar natural é o seam de propostas em `src/SignalNoir/Proposers/` (hoje: `Agent`,
  `AiHubRuntime`, `Replay`, `Rules`, `Unavailable`, escolhidos por `Factory`). Uma implementação
  `Decisions` produziria uma `Proposal` que passa pelo mesmo Validador.
- Mapeamento possível: `choice` sobre as quatro ações do catálogo fechado
  (`RETRY`, `APPLY_APPROVED_MAPPING`, `HOLD`, `REQUEST_REVIEW`), com `other` levando a
  `REQUEST_REVIEW`; `predicate` para sinais como "pedido ainda ativo"; `score` para severidade.
- Limiar de confiança abaixo do qual a Proposta vira `REQUEST_REVIEW`, nunca uma ação automática.
- Nada disso muda o Validador, a Aprovação nem a Execução. A API entra só antes deles.

## Generalização para sistemas críticos com interoperabilidade

Os padrões abaixo não dependem do laboratório e valem para qualquer integração crítica:

1. **Decidir separado de agir.** O serviço de decisão só produz respostas tipadas; uma camada com
   regras e autorização executa.
2. **Faixa de incerteza que vai a humano.** Probabilidades intermediárias ou `confidence` baixa
   encaminham para revisão, sem ação automática.
3. **Limiares calibrados e versionados.** Registrar limiar, conjunto de exemplos rotulados e versão
   da pergunta, para auditoria e comparação entre versões.
4. **`refusal` e `other` tratados explicitamente.** Nunca assumir um valor padrão quando a resposta
   não é útil.
5. **Idempotência na camada da aplicação.** O guia não documenta chave de idempotência; use uma
   chave de negócio própria para efeitos que podem ser repetidos.
6. **Contrato de interoperabilidade validado antes de propagar.** Conferir a forma de `answers` e
   usar `name` como chave de correlação; rejeitar respostas com nomes duplicados ou ausentes.
7. **Rastreabilidade completa.** Guardar entrada, perguntas, respostas, `confidence`,
   probabilidades, decisão final e quem aprovou.
8. **Monitoramento de uso e de deriva.** Acompanhar o endpoint de uso e a distribuição das
   respostas ao longo do tempo.
9. **Privacidade e residência antes do envio.** Confirmar elegibilidade (ZDR/HIPAA) e a região de
   processamento para dados sensíveis.
10. **Entradas estruturadas.** Serializar sistemas externos em `input_json` com esquema validado,
    sem misturar dados de terceiros com instruções.

## Pendências

- Verificar a página original e atualizar este documento (modelo, limites, campos).
- Decidir se vira um tipo de proposta no seam `Proposers/` (exige spec própria, por exemplo
  `specs/0XX-decisions-proposer/`). Nenhum código foi alterado por este documento.

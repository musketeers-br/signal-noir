# Spike 013: Decisions API através do AI Hub (build 154)

- **Spec:** [`specs/013-decisions-proposer/spec.md`](../../specs/013-decisions-proposer/spec.md), FR-014 e SC-005
- **Objetivo:** responder se o AI Hub build 154 consegue fazer uma chamada `decisions` pela
  configuração de provedor (`%AI.Provider`), como o Agent faz.
- **Resultado:** *pendente.* Preencha a seção "Resultado" ao final, com data, build, arquitetura e
  saídas. Não cole chave nem conteúdo de `.env`.

## Regras do spike

- Só dados sintéticos, gerados para o teste. Nenhum pedido real.
- A chave entra só pelo `.env` que o container já lê. Nunca imprima `SN_AI_API_KEY`, nunca a passe em
  linha de comando, nunca a grave em arquivo versionado.
- O spike **não cria o adaptador.** Nada de `SignalNoir.Proposers.Decisions` em `src/` neste passo.
- Se uma etapa falhar, pare, registre o erro no resultado e não improvise um cliente HTTP. Pela FR-014,
  um cliente HTTP direto exige nova decisão do usuário.

## Pré-requisitos

1. Imagem `signalnoir/iris-aihub:2026.3.0AI.154.0` carregada e retagueada
   ([`docs/ai-hub-start.md`](../ai-hub-start.md), passo 1).
2. `.env` com `SN_AI_PROVIDER`, `SN_AI_MODEL` e `SN_AI_API_KEY`.
3. Container no ar e saudável:

```bash
docker compose up -d
docker inspect --format '{{.State.Health.Status}}' "$(docker compose ps -q iris)"
```

## Etapa 1: inventário do que o AI Hub expõe

Descubra quais métodos e propriedades `%AI.*` existem nesta build. Procure por `Decision` e por
qualquer rota de endpoint além de chat.

```bash
docker compose exec -T iris iris session IRIS -U SIGNALNOIR <<'EOF'
Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT parent, Name FROM %Dictionary.CompiledMethod WHERE parent %STARTSWITH 'AI.' OR parent %STARTSWITH '%AI.' ORDER BY parent, Name")
While rs.%Next() { Write rs.%Get("parent"), " ", rs.%Get("Name"), ! }
Halt
EOF
```

Repita a consulta com `Name [ 'ecision'` e com `Name [ 'Responses'`. Registre a lista completa de
classes `%AI.*` (`%Dictionary.CompiledClass`) no resultado.

**Critério de saída desta etapa:**

- Se nenhum método ou classe de `%AI.*` mencionar decisões ou um endpoint `/v1/decisions`, registre
  "não exposto pelo AI Hub build 154" e **pare aqui**. A FR-014 então bloqueia a spec. Volte ao usuário.
- Se houver um caminho, siga para a etapa 2.

## Etapa 2: chamada pelo caminho do AI Hub

Use o provedor configurado no `.env`, pela mesma criação que o `AiHubRuntime` usa (ver
`src/SignalNoir/Proposers/AiHubRuntime.cls`). Só use o caminho que a etapa 1 encontrou.

Chame com duas perguntas, uma `choice` sobre as quatro ações do catálogo mais `other`, e uma
`predicate`. Entrada: um pacote de evidência sintético com um pedido de teste.

Registre:

- o formato bruto da resposta (campos, nomes, `probabilities`, `confidence`);
- a latência e os tokens de entrada e saída, se o AI Hub reportar;
- se o `name` de cada pergunta volta igual ao enviado.

## Etapa 3: falhas mapeadas para valor

Provoque ao menos duas falhas e confirme que cada uma vira valor de erro, sem exceção, sem Proposta
e sem vazamento de chave:

1. **Modelo inexistente** (por exemplo, `SN_AI_MODEL` trocado para um nome falso, em um ambiente de
   teste). Esperado: erro do provedor mapeado para `provider_unavailable`.
2. **Chave inválida** (chave de teste falsa). Esperado: `provider_unavailable`. Confirme que a chave
   não aparece no log nem na mensagem de erro.

Restaure o `.env` original ao final e rode `docker compose down` e `up` para recarregar a
configuração.

Se o AI Hub não separar `refusal` de erro, registre isso. Ele afeta a FR-007.

## Etapa 4: verificação de vazamento

```bash
docker compose logs iris | grep -c "$(grep '^SN_AI_API_KEY=' .env | cut -d= -f2-)"
```

O resultado esperado é `0`. Se não for, pare, remova a linha afetada do registro e trate o log como
incidente. Não cole o log no resultado.

## Resultado

Preencha ao final:

| Campo | Valor |
|---|---|
| Data | |
| Build | 2026.3.0AI.154.0 |
| Arquitetura | |
| Etapa 1: caminho encontrado | sim / não |
| Etapa 2: chamada `choice` e `predicate` | ok / falhou |
| Etapa 3: falhas mapeadas | |
| Etapa 4: vazamento de chave | 0 / encontrado |
| Decisão | prosseguir para o plano / bloqueado |

### Execução de 2026-10-30 (parcial, bloqueada na etapa 1)

- **Container.** `docker compose up -d` falhou: a porta 1972 já estava alocada pelo container
  `signalnoir-iris` (imagem `signalnoir-dev:154c`, no ar há 4 dias). Esse container não foi parado nem
  alterado. O spike foi conduzido contra ele, que reporta `status: ready` e `provider.configured: 1` em
  `/signalnoir/api/v1/health`.
- **Etapa 1 (inventário): não executada.** `iris session` como `SIGNALNOIR` retornou `Access Denied`. O
  repositório não guarda credenciais de IRIS, e o `.env` só traz `SN_*`. Não tentei outras credenciais.
- **Etapa 2 (chamada `choice`/`predicate`): não executada.** Depende da etapa 1, porque sem saber se o
  AI Hub expõe `decisions` não há caminho válido a testar. Chamar a API direto pelo `curl` não responde
  à FR-014, porque a rota proibida é justamente essa.
- **Etapa 3 (falhas mapeadas): não executada.** Exige alterar o `.env` e recriar o container, o que
  afetaria o `signalnoir-iris` em uso. Não foi feito sem aprovação.
- **Etapa 4 (vazamento de chave): não executada.** Depende das etapas anteriores.
- **Decisão:** *pendente.* Sem a etapa 1 a FR-014 não fica satisfeita; a spec segue bloqueada.

Para destravar a etapa 1, rode no terminal (ele pede a senha de forma interativa):

```bash
docker exec -it signalnoir-iris iris session IRIS -U SIGNALNOIR
```

Depois cole a consulta da etapa 1 deste roteiro e envie o resultado.

Saídas relevantes (sem chave, sem `.env`): nenhuma até o momento.

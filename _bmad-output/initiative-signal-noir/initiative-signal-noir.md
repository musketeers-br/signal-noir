---
type: initiative
title: 'Signal Noir: AI Exception Resolution for Interoperability'
parent: none
updated: 2026-10-25
sources: [_bmad-output/initiative-signal-noir/prd-signal-noir/prd-signal-noir.md, _bmad-output/initiative-signal-noir/prd-signal-noir/addendum.md, _bmad-output/initiative-signal-noir/reconcile-fontes-2026-10-20.md, _bmad-output/initiative-signal-noir/architecture-signal-noir/architecture-signal-noir.md]
companions: [_bmad-output/initiative-signal-noir/architecture-signal-noir/architecture-signal-noir.md, _bmad-output/initiative-signal-noir/ux-signal-noir/DESIGN.md, _bmad-output/initiative-signal-noir/ux-signal-noir/EXPERIENCE.md, contracts/openapi-signalnoir.yaml, contracts/openapi-sim.yaml, _bmad-output/initiative-signal-noir/tickets/epic-prototipo-solucao/epic-prototipo-solucao.md, specs/, docs/specify-prompts/PARALELISMO.md]
---

# Signal Noir: AI Exception Resolution for Interoperability

## Description

O Signal Noir transforma uma falha de integração numa decisão operacional verificável. Quando um Pedido laboratorial sintético falha numa Production IRIS, o sistema abre um Caso. Um Agente do IRIS AI Hub (build 154) investiga com Ferramentas de leitura e propõe uma Ação de um catálogo fechado. A aplicação valida a proposta, pede Aprovação humana, revalida, executa com idempotência e confirma o resultado. Quando não há decisão segura, o Operador recebe um Dossiê de Revisão útil.

A iniciativa é a submissão do time Musketeers (Henry, José Roberto e Henrique) ao *InterSystems Programming Contest: AI Agents in Interoperability Workflows*. A construção vai de 26/10 a 08/11/2026.

Estes Requirements destilam o PRD e o addendum finais de 18/10, a proposta de 16/10 e o caderno de decisão de 19/10. Onde as fontes divergem, vale o caderno de 19/10, que é o mais recente. A comparação está em `reconcile-fontes-2026-10-20.md`. O próprio caderno é uma proposta: ainda falta a revisão conjunta de Henry e José. As questões dessa revisão estão em Notes.

O vocabulário segue o Glossário do PRD (§3). Os itens B01–B14 são o backlog do caderno. Cada um está dentro de um épico em `tickets/`.

## Outcome

- Uma decisão real do AI Hub, tomada dentro da Production, muda o desfecho do workflow no cenário principal P5/P8b. Isso pode ser conferido na interface e no Visual Trace.
- Sem decisão segura, o Operador recebe um Dossiê que diz o que falhou, o que foi consultado e qual é o próximo passo.
- Nenhum efeito duplicado e nenhum envio com contexto vencido, mesmo com resposta perdida, clique repetido, reinício ou worker atrasado.
- Um Benchmark honesto e reproduzível: o ganho do Agente sobre o Modo Regras é medido e publicado, inclusive se der empate ou perda.
- Antes de 26/10, um protótipo navegável em HTML, CSS e JS mostra ao time como a solução final vai parecer e se comportar.
- Uma submissão que outro integrante instala apenas seguindo o README.

## Requirements

### Escopo e tese
- R1 (FR-9; caderno ADR-01) O núcleo trata um Pedido sintético com uma Exceção principal por vez, nas Famílias P5 e P8b. Nele, um Agente do AI Hub build 154, invocado de dentro da Production, propõe uma Ação que altera o desfecho do Caso.
- R2 (FR-28, FR-29; caderno §01 "P13 no núcleo") O Dossiê de Revisão (P13) faz parte do núcleo. Ele entrega valor quando o Agente não decide com segurança e também quando o LLM falha antes de propor.
- R3 (FR-20 a FR-23, FR-31; caderno ADR-01) A Família P3 (o contexto muda entre a Aprovação e a Execução) e a suíte de recuperação são obrigatórias. Os resultados delas são reportados como Garantias da Plataforma, nunca como mérito do Agente.
- R4 (FR-24, FR-47; caderno §02) P9 é condicionado. Só entra depois de B09 e B10 aceitos, e sem comprometer B12–B14. Um Recibo candidato sem identidade inequívoca leva o Caso a revisão, nunca a encerramento automático.
- R5 (FR-31; caderno §02) P1 entra apenas como variante de P5. A demonstração não tem espera real de 90 s.
- R6 (SM-1, SM-2; caderno ADR-01, §06) O ganho do Agente sobre o Modo Regras é uma hipótese medida, sem meta de vitória. Empates e perdas são publicados, e a linha de base não é enfraquecida.

### Pedido, Caso e estados
- R7 (FR-1, FR-2) Pedidos JSON são validados na entrada e recebem correlação. Só um Recibo válido conta como sucesso.
- R8 (FR-3, FR-4; caderno ADR-02) O Caso persistente é a fonte de verdade da resolução. A Production transporta mensagens e executa etapas curtas. A espera humana é persistida e não ocupa um job bloqueado. Uma Aprovação gera trabalho novo pelo outbox.
- R9 (FR-5; caderno ADR-03) Há uma única máquina de estados. B01 a congela com origem, destino, ator, pré-condições, evento e trabalho subsequente de cada transição.
- R10 (FR-3, FR-5; caderno ADR-03) Estados terminais não reabrem implicitamente. Um novo episódio depois de um estado terminal cria um Caso relacionado. Rejeição e expiração têm destino e limite. `Held` só sai por nova Investigação.
- R11 (FR-6, FR-7) Evidência, Diagnóstico, Proposta, Aprovação, Execução e Recibo são registros separados e vinculados. A Linha do Tempo é append-only. Se a autorização não for registrada, a Execução não acontece.

### Investigação e Proposta
- R12 (FR-10, FR-11, FR-53; caderno ADR-08) O Agente só tem Ferramentas de leitura. O servidor impõe o contexto e o orçamento. A Evidência Pré-coletada substitui as Ferramentas como plano B, mas a chamada real ao AI Hub continua.
- R13 (FR-12) A Proposta é estruturada: Diagnóstico, Ação e parâmetros, Escopo, Confiança, pré-condições, hipóteses descartadas e referências a Evidências.
- R14 (FR-13; B08) Conteúdo de Pedidos, respostas e logs é tratado como dado. Testes com instrução embutida registram a decisão e o bloqueio.
- R15 (FR-12; B08) Uma resposta tardia do Agente não altera uma Investigação já encerrada.
- R16 (FR-9, NFR-9; B02) Cada Investigação registra modelo, Provedor, versões, duração, Chamadas de Ferramenta e tokens, quando disponíveis.
- R17 (FR-50; caderno §02, ADR-08) Um Provedor e um modelo de referência são demonstrados. A troca por `.env` continua possível, mas o suporte aos quatro Provedores não é garantido nem anunciado.

### Validação e Ações
- R18 (FR-14, FR-15; caderno ADR-07) Um único Validador determinístico recebe as Propostas do Agente, do Modo Regras, do Operador e do Benchmark. Ele verifica catálogo, parâmetros, aplicabilidade, Evidências mínimas e condições.
- R19 (FR-16; caderno §02, tabela de Ações) O catálogo tem quatro Ações:
  - `RETRY` e `APPLY_APPROVED_MAPPING` exigem Aprovação humana fora do Benchmark;
  - `HOLD` entra sem Aprovação, e a saída exige nova Investigação;
  - `REQUEST_REVIEW` interrompe a automação sem efeito externo.
- R20 (FR-14; caderno §02) `APPLY_APPROVED_MAPPING` só aplica um Mapeamento existente e versionado cuja condição bate com o Pedido.

### Aprovação
- R21 (FR-17; caderno ADR-06) A Aprovação referencia uma Proposta imutável: Ação, parâmetros, payload transformado e as versões relevantes.
- R22 (FR-18; caderno ADR-06) A Aprovação vale por prazo e passa por Revalidação. Uma Aprovação vencida ou materialmente incompatível não executa. Uma Evidência nova qualquer não a expira.
- R23 (FR-19; B06) Duas Aprovações concorrentes resultam em uma única autorização efetiva. Uma Proposta vencida ou substituída é recusada.

### Execução, identidade e recuperação
- R24 (FR-22; caderno ADR-04) Há três identidades separadas:
  - `commandId` para o trabalho interno;
  - `executionId` para a execução autorizada, seu lease e sua Reconciliação;
  - `businessEffectKey` para o efeito no Parceiro.

  A identidade do efeito não depende só de `proposalId`.
- R25 (FR-22; caderno ADR-04; B05) O Parceiro deduplica atomicamente chave e payload. Para a mesma chave e o mesmo payload, devolve o Recibo original. Rejeita a mesma chave com payload incompatível.
- R26 (FR-21, FR-23; caderno ADR-04) A autorização é persistida antes do efeito. Um resultado incerto bloqueia qualquer novo envio, inclusive por uma nova Proposta, até a Reconciliação.
- R27 (FR-20; caderno §02 P3) A Revalidação roda imediatamente antes do envio. Uma condição impeditiva bloqueia o envio. A saída da espera exige nova Proposta e, quando aplicável, nova Aprovação.
- R28 (FR-4; caderno ADR-05) Estado, evento e outbox confirmam juntos, sem I/O externo na transação. O transporte admite reentrega. O lease tem identidade de posse e de geração. Um worker atrasado não sobrescreve uma execução posterior. A leitura incremental não perde eventos confirmados tarde.
- R29 (NFR-5, NFR-6; caderno §06) A suíte de recuperação exercita:
  - resposta perdida após aceitação;
  - clique repetido;
  - reinício durante a Execução;
  - comando repetido;
  - worker atrasado;
  - pré-condição impeditiva.

### Dossiê de Revisão
- R30 (FR-28; B10) O Dossiê traz o motivo, as Evidências consultadas, as divergências e o próximo passo concreto. Nenhuma consulta ou Evidência é inventada. Ausência de informação aparece separada de conclusão negativa.
- R31 (FR-29; B10) A decisão humana passa pelo mesmo Validador. Cancelamento e autoria declarada ficam registrados. Não há edição livre de payload.

### Interface do Operador
- R32 (FR-34, FR-35, FR-36; caderno ADR-09; AD-17) A interface é uma SPA estática, com polling e contratos HTTP versionados. Ela oferece lista, detalhe em camadas, Aprovação, Dossiê e resultado, e mostra o problema, as Evidências, a alteração prevista e o resultado.
- R33 (FR-36; caderno ADR-09; B07) A Aprovação mostra o efeito exato e envia a versão exata. Um conflito de versão exige atualizar a Proposta. Uma recusa do servidor nunca aparece como sucesso.
- R34 (FR-35; B03, B07) Fato observado e diagnóstico são distinguíveis. Espera, revisão e incerteza têm mensagens distintas. Falha do Provedor e ausência de dados têm apresentação própria.
- R35 (FR-37, FR-38; caderno ADR-09) A interface marca dados sintéticos, mostra o nome do Operador como identificação declarada e dá acesso ao Visual Trace do Pedido.

### Protótipo da solução
- R36 (reconcile §4) Antes de 26/10, um protótipo descartável em HTML, CSS e JavaScript puros dá ao time e aos revisores uma noção concreta da solução final. Ele percorre P5/P8b, P13, P3 e a recuperação com dados sintéticos, sem backend e sem build.
- R37 (reconcile §4; AD-16) As fixtures do protótipo usam os nomes, estados, Ações e códigos de erro de `contracts/openapi-signalnoir.yaml`. Uma divergência encontrada vira proposta de mudança de contrato em B03, nunca ajuste silencioso.
- R38 (reconcile §4; PRD Q-1, Q-2) O protótipo é material de preparação. Não vira código da submissão, não é copiado para `ui/` nem para a imagem e não reaproveita código do SentaiTask.
- R39 (reconcile §4) Os aprendizados do protótipo são registrados e alimentam B03, uma rodada de `bmad-ux` e os critérios de B07 e B10.

### Simulador e Cenários
- R40 (FR-30 a FR-33; B05) O Simulador é acessado por HTTP e:
  - isola as instâncias;
  - reproduz o cenário a partir de uma semente;
  - pode aceitar o Pedido e perder a resposta;
  - torna sincronizável uma mudança pós-Aprovação;
  - não expõe o Gabarito por nenhuma Ferramenta.
- R41 (FR-32, FR-33; B01) B01 fixa:
  - a separação entre ajuste e teste;
  - o Gabarito prévio, inclusive os casos em que `REQUEST_REVIEW` é o correto;
  - os negativos de mapeamento, identidade e Recibo;
  - a regra de novo episódio.

### Benchmark
- R42 (FR-39, FR-48; caderno ADR-10; B11) Regras e Agente usam as mesmas Ferramentas e proteções. A pontuação considera Ação e parâmetros. O relatório separa:
  - revisão necessária de revisão desnecessária;
  - proposta errada bloqueada de efeito errado.

  A Aprovação Automática só existe no Benchmark.
- R43 (FR-40; caderno §06; B12) A Execução de Referência cobre P5 e P8b, com 5 variantes por Família e 3 repetições (30 investigações de teste), mais controles limpos e Dossiê. Prompt, modelo, baseline, políticas, fixtures e avaliador ficam congelados antes do teste. O relatório publica contagens, denominadores, dispersão, latência, custo e dados brutos. As repetições não contam como casos independentes.
- R44 (SM-C2; caderno §06) Ajustar a solução com resultados do teste transforma esse conjunto em desenvolvimento. O resultado final passa a exigir um novo teste reservado válido.
- R45 (FR-41; B12) Uma resposta gravada (Replay) não conta como execução real.
- R46 (FR-48; caderno §06) A independência é garantida por divisão de papéis: Henry prepara os casos reservados, José escreve o baseline a partir do contrato e do ajuste, e Henrique revisa o avaliador.

### Empacotamento e entrega
- R47 (FR-42, FR-44; caderno ADR-11) A solução usa a imagem local do build 154, com bootstrap idempotente e segredos fornecidos em execução. Reinício, recriação e reset são testados e documentados. Nenhuma imagem EAP, nem derivada, vai para registry público.
- R48 (FR-44; B04, B13) Sem chave válida, o app sobe e informa a indisponibilidade. Segredos não aparecem em código, eventos, logs nem exports.
- R49 (FR-42, FR-43; B13) A instalação cruzada segue só o README, com smoke real usando chave própria. Plataforma não testada não é anunciada como validada. Uma correção que afete a instalação dispara nova validação.
- R50 (FR-43, FR-45, FR-52; caderno ADR-12; B14) O pacote final tem README em inglês, licença, vídeo da versão entregue com dados sintéticos, limitações, perfis e inscrição verificada. Só o escopo demonstrado é anunciado, e os resultados divulgados correspondem ao relatório.

## Constraints

- O código da submissão começa em 26/10/2026. Antes disso, só contratos, especificação, fixtures, o protótipo descartável (R36–R38) e o spike fora do repositório (PRD Q-1, Q-2).
- O build 154 do AI Hub EAP é obrigatório. O build 162 não é aceito.
- Todos os dados são sintéticos. Não há decisão clínica nem edição livre de payload.
- As datas internas estão em BRT. O prazo do edital (08/11, 23:59 EST) equivale a 09/11, 01:59 BRT. A meta interna é 07/11, e 08/11 fica como margem.
- A arquitetura vigente é `architecture-signal-noir.md` (AD-1 a AD-28), com contratos HTTP primeiro (AD-16).
- Fonte de verdade da execução: `specs/` (speckit) e o board de `docs/specify-prompts/PARALELISMO.md`. Os épicos e os tickets deste arquivo seguem esse board. Divergência de escopo ou de contrato vira `contract-change` na spec, nunca ajuste silencioso aqui.
- Gates de integração (PARALELISMO): G0 = 001; G1 = 002, 003, 004; G2 = 005, 006, 007; G3 = 008, 009; G4 = 010, 011 (condicional), 012. Os gates não têm datas no board; as datas dos marcos abaixo continuam sendo a meta do concurso.
- Capacidade: resolvida pelo board. O simulador HTTP é da Henrique (spec 002), e o Caso, o Agente, a console e o Dossiê são do Henry (specs 003, 006, 005, 009). José saiu da implementação em 24/10 e volta só na onda 5, para a revisão do baseline e do avaliador (010) e para a 011 condicional.
- Responsáveis por frente (board):
  - **Henrique:** protótipo, contratos (B03), Simulador (002), Validador (004), Aprovação e outbox (007), Execução e recuperação (008), runner e scoring do benchmark (010) e integração dos gates;
  - **Henry:** Caso e Pedido (003), Agente e Investigação (006), console (005), Dossiê (009), baseline de regras (010), pacote e README (012), e o conteúdo e a rubrica do Dossiê;
  - **José:** saiu para outro projeto. Suas specs passam para o dono da iniciativa: 001 (concluída, com T045 aberta), a revisão do baseline e do avaliador do 010 no primeiro dia da onda 5, a 011 condicional, e a verificação com iris-agentic-dev (V1–V6 da 002 e V1–V3 da 004). O B02 (spike do build 154) segue sem dono (ver Notes).
- Verificação ao vivo: a constituição exige iris-agentic-dev para qualquer interação com o IRIS, inclusive `%UnitTest`. Ele é o que registra V1–V6 da 002 e V1–V3 da 004, e bloqueia o gate `/speckit-implement` dessas specs. Cada pessoa configura o próprio `.iris-agentic-dev.toml`, que o git ignora por guardar credenciais.
- Ordem de ondas (mensagem da Henrique): onda 1 = 002 e 003; 2 = 004 e 006 (com fake do Validador); 3 = 007 e 005; 4 = 008 e 009 + baseline de regras; 5 = 010 (runner, scoring, variantes reservadas), 012 e revisão do baseline e do avaliador → 011, se der tempo. O baseline e o scoring precisam estar prontos no começo da onda 5, então sobem para a onda 4.
- Cada marco tem uma prova e um corte:

| Data | Prova | Se falhar |
|---|---|---|
| 24/10 | Protótipo navegável revisado por Henry e José | B03 congela com o que o protótipo já mostrou; o restante vai para Notes |
| 25/10 | B01, B02 e B03 entregues | Evidência Pré-coletada (FR-53) se o Agente não chamar Ferramentas na Production |
| 27/10 | Agente em BO; Proposta persistida e recuperável | Suspender amplitude de cenários e benchmark comparativo |
| 29/10 | P5/P8b completo na interface, da falha ao resultado | Retirar P9 e manter uma história principal |
| 02/11 | Aprovação, Revalidação e Reconciliação comprovadas | Restringir as Ações executáveis às testadas |
| 05/11 | Freeze funcional; referência executada; demo ensaiável | Só correções e preparação da entrega |
| 07/11 | Instalação cruzada e inscrição verificadas | 08/11 é margem operacional |

## Done when

- Outro integrante instala e roda o smoke seguindo só o README (R49).
- Uma decisão real do AI Hub altera o resultado do workflow em P5/P8b (R1).
- Casos sem Evidência suficiente ficam em revisão com Dossiê útil, inclusive com falha do LLM (R2, R30).
- Aprovação e Execução são rastreáveis e sobrevivem a reinício. Timeout, repetição e worker atrasado não duplicam efeitos (R23–R29).
- A Execução de Referência foi rodada, congelada e publicada com dados brutos, mesmo que o resultado seja empate ou perda (R43, R6).
- Vídeo, documentação, dados sintéticos e limitações estão identificados, e a inscrição está verificada (R50).
- O protótipo foi revisado e seus aprendizados foram registrados antes de 26/10 (R36, R39).

## Boundaries

- Non-goal: Incidentes e lotes, Escopo `batch`, P2.
- Non-goal: canvas, editor de Productions, geração de código.
- Non-goal: System 1, busca semântica, fine-tuning, HL7/FHIR, múltiplos agentes.
- Non-goal: suporte garantido aos quatro Provedores; Replay executável na interface.
- Non-goal: autenticação e perfis. O Operador só se identifica pelo nome.
- Non-goal: decisão clínica e edição livre de payload.
- Non-goal: protótipo com backend, build, framework ou integração real.
- Touch point: IRIS AI Hub EAP build 154 (`%AI.Agent`, `%AI.ToolSet`, `%AI.Provider`) — consumido, não desenvolvido; owner: epic-contratos-e-spike (spike) e epic-fundacao-e-simulador (imagem e bootstrap).
- Touch point: Visual Trace da Production — só linkado a partir do Caso; owner: epic-interface-e-dossie.
- Touch point: Open Exchange e página do concurso — publicação e inscrição; owner: epic-entrega.
- Tracer path: um Pedido sintético P5/P8b sai do Simulador (épico 3), vira Caso e Proposta validada (épico 4), aparece e é aprovado na interface (épico 5), é executado com Revalidação e Recibo (épico 6) e entra na Execução de Referência (épico 8) que a entrega publica (épico 9).

## References

- prd — _bmad-output/initiative-signal-noir/prd-signal-noir/prd-signal-noir.md (§3 Glossário, §9 escopo, §11 roteiro da demo)
- addendum — _bmad-output/initiative-signal-noir/prd-signal-noir/addendum.md (§D transições, §E Famílias, §F roteiro)
- reconcile — _bmad-output/initiative-signal-noir/reconcile-fontes-2026-10-20.md (§7 índice do caderno de 19/10)
- architecture — _bmad-output/initiative-signal-noir/architecture-signal-noir/architecture-signal-noir.md
- design — _bmad-output/initiative-signal-noir/ux-signal-noir/DESIGN.md
- experience — _bmad-output/initiative-signal-noir/ux-signal-noir/EXPERIENCE.md
- contract — contracts/openapi-signalnoir.yaml
- contract — contracts/openapi-sim.yaml
- breakdown — _bmad-output/initiative-signal-noir/tickets/tickets.toml

## Notes

- Decision (21/10): o primeiro épico é o protótipo, e não uma base de plataforma, porque nenhum código da submissão pode ser escrito antes de 26/10 (Q-1). A base da plataforma é o épico 3 (B04), depois dos contratos do épico 2.
- Assumption: o caderno de 19/10 prevalece sobre o PRD de 18/10 onde os dois divergem (SM-1, Famílias da referência, Provedores, expiração da Aprovação, identidades). O PRD e a arquitetura ainda não foram atualizados (ver reconcile).
- Decision (20/10, Henrique): o protótipo é responsabilidade de Henrique, com revisão de Henry (domínio) e José (contratos).
- Decision (20/10, Henrique): o texto do protótipo e da interface final fica em inglês.
- Open question: o núcleo P5/P8b + P13 atende ao objetivo do produto e da competição? (revisão Henry + José)
- Resolved (board, 25/10): o simulador HTTP é da Henrique (002), e o benchmark é dividido entre Henrique (runner e scoring), Henry (baseline) e José (revisão). Ver Constraints.
- Open question: o spike do build 154 (B02) não tem dono ativo, porque o José saiu da implementação em 24/10. Decidir antes de 26/10 quem prova o build 154 e o fallback.
- Open question: o calendário fala em código só a partir de 26/10 (PARALELISMO, regra 7), mas há commits de implementação de 003, 005, 006 e 009 em 25/10 (horário local), e a spec 009 diz "Implemented (2026-10-26)". Confirmar a data de referência e se esse trabalho entra no repositório como está.
- Open question: a tarefa T045 da spec 001 (aprovação de `contract-change` 001 por um segundo membro) segue aberta. Ela bloqueia o fechamento do G0.
- Open question: specs 004, 007, 008, 010, 011 e 012 não têm pasta em `specs/`, só o prompt em `docs/specify-prompts/`. Os épicos 4, 6, 7, 8 e 9 seguem sem spec e não podem ser planejados até lá. A spec 002 só tem `spec.md`, sem plan nem tasks, apesar de o board dizer "spec/plan/tasks prontos".
- Open question: o protótipo (épico 1) não tem spec no speckit. Ele segue como material de preparação, e a revisão de 24/10 não aparece registrada.
- Open question: o contrato do Recibo e da identidade do efeito (`businessEffectKey`) está claro? Isso exige atualizar o AD-21 e `openapi-sim.yaml`.
- Open question: o time aceita que P9 seja condicionado e possa terminar em revisão?
- Open question: o spike do build 154 tem dono, prova esperada e fallback? (era o José, que saiu da implementação; ver a questão acima; Q-A a Q-F da arquitetura)
- Open question: a revisão conjunta de Execução e retomada (antes previa José) agora é só da Henrique (008), porque o José está fora da implementação até a onda 5. Decidir se a revisão sai do time ou se o José volta antes.
- Open question: os marcos de corte e a inscrição em 07/11 são viáveis?
- Open question: Q-1 (PRD). Material de preparação no repositório, inclusive o protótipo, é aceito pelo edital? Se não for, o protótipo sai do repositório antes de 26/10. Responsável: Henry, no Discord.
- Open question: Q-3, Q-4, Q-5, Q-9, Q-11 e Q-13 do PRD continuam abertas, com os responsáveis já registrados.
- Open question (iris-agentic-dev, 25/10): a mensagem diz que a ferramenta não está no PATH e que `.iris-agentic-dev.toml` não existe nesta máquina. Aqui, o binário está em `/opt/homebrew/bin/iris-agentic-dev` e o `.iris-agentic-dev.toml` existe. Confirmar em qual máquina o gate foi testado. A forma de instalação para cada integrante continua sem registro: perguntar ao José antes de ele sair, com o comando de instalação do skill pack. Prazo: V1–V6 da 002 e V1–V3 da 004 antes de 26/10.
- Open question (PR #9, 25/10): a 002 foi mergeada em master só com a spec (021cd3f). Henry precisa ser avisado de que a 002 não está aceita. Plan, tasks e remediações (d95597f, 0240332, 3dc57ef) não estão nesta clone; subir a branch 002-scenario-simulator e revisar antes do G1.

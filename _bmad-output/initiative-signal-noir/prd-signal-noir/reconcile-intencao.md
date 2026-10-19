# Reconciliação: intenção do brainstorming × PRD + addendum

- **Fonte de intenção:** `_bmad-output/brainstorm-lacunas-prd-sentai-nexus/brainstorm-lacunas-prd-sentai-nexus.md` (com `.memlog.md` para detalhe)
- **Alvo:** `prd-signal-noir.md` e `addendum.md` (nesta pasta)
- **Data:** 18/10/2026
- **Escopo:** o que a intenção contém e o PRD/addendum omitiu, enfraqueceu, contradisse ou mudou sem dizer. O PRD não foi editado.

Severidade: **Alta** = afeta a tese, o caminho crítico ou a coerência da demo; **Média** = requisito ou decisão perdida que a arquitetura/UX vai precisar; **Baixa** = nuance, rastreabilidade ou redação.

---

## 1. Lacunas

| # | Item da intenção | Fonte | PRD / addendum | Sev. | Sugestão |
|---|---|---|---|---|---|
| G1 | Contrato dos Cenários sujos fechado entre Henry e a frente IRIS **entre 16/10 e 25/10** (caminho crítico da tese) | Intenção §7 "Caminho crítico"; §9 "O diferencial mora no simulador" | PRD §9.4 "Frentes": "contrato fechado entre Henry e José **antes de 29/10**" | **Alta** | Mudança de prazo silenciosa: o contrato passa a coincidir com a integração real UI/simulador (29/10), anulando a folga. Restaurar 25/10 como data do contrato (é preparação, permitida pelo edital mesmo com o [NOTE FOR PM] de §9.4) e incluir "especificação dos Cenários P3/P5/P8/P9 congelada" como critério do marco de 25/10. |
| G2 | UJ-1/Momento 2 deveria mostrar P5 **+ P8** com o desfecho correto de cada família | Intenção §2 (P8: "pondera a confiabilidade das fontes"); §5 M2 | PRD UJ-1 passo 2: healthcheck `UP` mas "as entregas recentes falham" → termina em `APPLY_APPROVED_MAPPING`; addendum E, P8: healthcheck UP com falhas reais → desfecho correto **HOLD** | **Alta** | UJ-1 é internamente contraditória: contém o sinal P8 (parceiro degradado) mas aplica mapeamento e reenvia. Além disso, termina no padrão "código substituído → mapeamento aprovado", justamente o que a intenção tirou da abertura. Reescrever UJ-1 usando a variante P8 de **dois mapeamentos distinguíveis pelo contexto** (tipo de amostra, unidade, idade), ou remover o sinal "entregas recentes falham". Hoje nenhuma UJ cobre a variante "dois mapeamentos". |
| G3 | P2 é a 1ª capacidade da tabela e aparece no Momento 6 (flash) e no freeze "5 cenários sujos" | Intenção §2, §5 M6, §7 (05/11) | PRD §9.2 rebaixa P2/Incidentes a P1 condicional, mas §10 Momento 6 e UJ-5 continuam contando com ela; §9.4 05/11 diz "Famílias sujas" sem número | **Alta** | Consequência não tratada da mudança intencional: a demo enxuta e o placar não têm fallback se P2 não entrar. Declarar em §10 a versão do Momento 6 sem P2, e no marco 05/11 dizer explicitamente "4 Famílias (P3, P5, P8, P9) + P2 se o 02/11 passou". |
| G4 | P3 inclui a capacidade do agente de **avaliar tendência** (DOWN→UP com erro alto) e **condicionar a ação a pré-condições verificáveis na execução**; variante "entra manutenção" | Intenção §2, P3; memlog "pré-condições dinâmicas" | FR-20 tem lista fixa de checagens do sistema; UJ-2/FR-20/addendum E só tratam "parceiro volta a falhar" e "pedido cancelado". `preconditions[]` existe só no schema (addendum C), sem FR | **Média** | Adicionar a FR-12 que a Proposta declara pré-condições verificáveis e a FR-20 que a Revalidação checa essas pré-condições, além das fixas. Incluir a variante "janela de manutenção iniciada" em P3 (addendum E) e o sub-caso "healthcheck voltou mas a taxa de erro segue alta" na Investigação, não só pós-Aprovação. |
| G5 | Placar-meta incluía o resto do mundo sujo: agente 4/5 correto **+ 1/5 revisão segura** (ou seja, 0 incorreto) | Intenção §6 "Placar do benchmark" | SM-1 só traz ≥80% vs ≤40%; SM-5 mede revisão segura sobre outro denominador (variantes cujo gabarito é review); não há meta de **taxa de desfecho incorreto** do agente | **Média** | Acrescentar SM com teto para desfecho incorreto/Ação indevida do agente nas Famílias sujas (por exemplo ≤5%), já que FR-33 classifica em correto/revisão segura/incorreto. Assim a meta original "nunca errado, no pior caso revisão" não se perde na reformulação em taxas. |
| G6 | Qualidade do handoff (Dossiê P13) como **métrica do Benchmark**; P13 como "vitória do mundo sujo" | Intenção §9 (Dossiê) | FR-39 não lista métrica de Dossiê; FR-30 classifica "identidade ambígua" como Cenário **limpo** (onde os modos empatam) | **Média** | Definir uma métrica de completude do Dossiê (campos colididos, descartados e próximo passo presentes, conforme gabarito) em FR-39/FR-33, e esclarecer que no limpo o *desfecho* empata mas o *handoff* é comparado. |
| G7 | Escopo `queue_segment` | Intenção D5 | Glossário e addendum C: Escopo só `single_case` ou `batch` | **Média** | Mudança silenciosa. Se for corte deliberado, registrar em §8/§9.3 e no índice de suposições; senão, reintroduzir como valor reservado (não implementado na v1). |
| G8 | Critério de Caso novo: "nova mensagem distinta **ou episódio independente**"; reabertura como evento/transição posterior | Intenção D3, D6; §10 Q1 | FR-3 [ASSUMPTION]: Caso novo só com novo ID de pedido; Fase para nova Exceção. Nada sobre nova Exceção depois de um estado terminal nem sobre reabertura | **Média** | Declarar o que acontece com nova Exceção do mesmo Pedido após `Resolved`/`Cancelled` (novo Caso ligado ou reabertura). Adicionar a transição ao addendum D e manter a pergunta em §12 enquanto for suposição (hoje ela só está no índice §13). |
| G9 | Equivalência de Recibos / "mesmo pedido com outro ID" | Intenção §10 Q10 (Starbursting: definição formal de recibo e equivalência) | FR-24 diz "mesmo Pedido, ainda que com outro identificador"; UJ-3 e addendum E falam em "Pedido recente do **mesmo paciente sintético**" | **Média** | Falta o critério de correspondência que o P9 exige (quais campos tornam dois pedidos o mesmo efeito: paciente + exame + data de coleta?). Sem isso o gabarito do P9 e FR-24 não são testáveis. Adicionar ao addendum C/E e a §12. |
| G10 | Mensagens em HOLD: na fila IRIS suspensa ou só no Caso | Intenção §10 Q10 (Starbursting) | Ausente | **Média** | Afeta FR-27 ("nenhum Caso gera Tentativa") e a reconciliação de estado. Adicionar a §12 encaminhada à arquitetura. |
| G11 | Modelo Incidente/Lote: quem libera e como o Incidente evolui | Intenção §4 (P2) e §10 Q4 | FR-27 "Liberar o Incidente" sem dono nem gatilho; Incidente não tem estados | **Baixa** (P1 condicional) | Definir estados mínimos do Incidente (ativo, retido, liberado) e quem libera (Operador, Política ou recuperação do Parceiro). Pode ligar com Q-6/Q-7. |
| G12 | Dono do Caso e herança em troca de turno/reinício | Intenção §10 Q10 (Starbursting) | Ausente (§8 assume demo de usuário único) | **Baixa** | Registrar explicitamente como fora da v1 em §8, para não ficar como pergunta perdida. |
| G13 | Marcos: cortes detalhados | Intenção §7 | §9.4 resumiu: 25/10 perdeu "abandonar a narrativa de agente operacional"; 29/10 perdeu "cenários simultâneos" e "manter só a trilha mais forte", e o critério perdeu a cadeia completa (falha → evidências → investigação → proposta validada → aprovação → execução → resultado) e "cenário sujo **principal**"; 05/11 perdeu "Caso canônico persistido" e "sem comparação ampla" | **Média** | Restaurar o texto integral dos critérios e cortes; em especial a cadeia ponta a ponta de 29/10, que é o critério verificável. |
| G14 | D1: "MVP: 1 pedido sintético com 1 exceção principal por vez" | Intenção D1 | Ausente; o PRD não diz se P0 suporta Casos simultâneos | **Baixa** | Declarar em §9.1 se Casos concorrentes são P0 (P2 condicional exige; o corte de 29/10 da intenção os retira). |
| G15 | Confiança: o que ela mede | Intenção §10 Q2 | Formato decidido (ALTA/MEDIA/BAIXA) e roteamento BAIXA → review; não define o que mede nem o papel de MEDIA, nem relação com o veredito do Validador | **Baixa** | Definir semântica (robustez da evidência vs certeza do agente) e o tratamento de MEDIA (UJ-2 usa MEDIA com RETRY: exige Aprovação? Sempre?). |
| G16 | Fonte de verdade = modelo persistente do Nexus; Visual Trace/logs entram como Evidência referenciada ou anexada | Intenção D2 | §4.1 diz "A Production é a dona do estado do workflow"; Visual Trace só como link (FR-37), não como Evidência; Q-10 adia a divergência | **Baixa** | Explicitar que o Caso (modelo Nexus) é a fonte de verdade da *resolução* e a Production do *transporte*, e permitir Evidência do tipo "referência ao Visual Trace". |
| G17 | P1 embutido em **P9** no Momento 3 | Intenção §5 M3 "P9 (+P1)" | PRD §10 põe P1 no Momento 2 (P5+P8) e FR-31 o chama de variante de P5/P8; addendum F mantém "P9 com P1" | **Baixa** | Contradição interna entre PRD e addendum. Escolher um lugar e alinhar FR-31, §10 e addendum F. |
| G18 | Fora de escopo: P10 e P12 | Intenção §2 "Fora da submissão" | §9.3 lista P4, P6, P7, P11, mas não P10 (contexto/SLA) nem P12 (200 com semântica errada) | **Baixa** | Acrescentar P10 e P12 a §9.3 (candidatos v2/artigo). |
| G19 | Validar NFRs com medição real no build 154 | Intenção §10 Q8 | NFR-2 a NFR-4 marcados [ASSUMPTION], mas sem tarefa/marco de medição; não estão em §12 | **Baixa** | Adicionar ao marco 29/10 ou 02/11 "1ª medição de latência e custo no build 154" e uma pergunta em §12. |
| G20 | Empate no limpo como **100%** | Intenção §1 | SM-2 tolera ≤5 pontos de diferença | **Baixa** | Aceitável pelo não determinismo do LLM, mas declarar a mudança e o motivo junto a SM-2. |

### Ideias qualitativas que o FR achatou

- **"O mundo limpo empata"**: preservado com força (§1, FR-30, SM-2, SM-C2). Ok.
- **"Aprovação não congela o mundo"**: preservado como título do Momento 5. Mas o conteúdo conceitual (a decisão carrega pré-condições que o mundo pode invalidar) foi reduzido a uma checagem fixa do sistema; ver G4.
- **Três eixos da tese** (decisões não locais, evidência imperfeita, contexto que muda): o PRD troca por 5 exemplos em §1. Sugestão: manter os três eixos como critério de aceite de um novo Cenário em §4.9 ("um Cenário sujo precisa quebrar ao menos um eixo"), o que torna operacional o princípio "não gerar variações cosméticas".
- **"Uma ideia só"** (diagnóstico + scope + Incidente): está no addendum G, mas o rebaixamento de Incidentes a P1 quebra a unidade. Vale dizer em §4.7 que o Escopo `batch` e o Diagnóstico continuam P0 mesmo sem Incidente.
- **"30 falhas não são 30 decisões"** e **"descobrir que o problema já não existe"**: só no addendum F. Ok para roteiro.
- **Comunidade "sem parecer perigosa nem artificial"**: aparece só no JTBD; nenhum requisito de tom/narrativa para o vídeo (FR-45). Baixa.
- **"Risco no 25/10: a menor prova só exercita o caminho limpo"**: o PRD manteve P5 como *desejável*, mas perdeu o porquê. Baixa.

---

## 2. Mudanças intencionais (registradas, não são lacunas)

- **P2/Incidentes rebaixados a P1 condicional** (§9.2), entrando se 02/11 for cumprido. Consequências não tratadas: G3, G11.
- **Meta do Benchmark reformulada em taxas sobre variantes** (SM-1 ≥80% vs ≤40%, conjunto de teste separado, SM-C2). Responde ao insight "um caso por cenário é anedota". Consequência: G5.
- **Questões resolvidas por suposição:** Confiança ALTA/MEDIA/BAIXA; estados `Cancelled`, `ResolvedByPriorReceipt`, `Failed` adotados com transições da Revalidação (addendum D); TTL de 15 min; Fase como mecanismo de "mesmo Caso"; P1 como variante; P2 como flash de 15 s; Operador resolve Dossiê escolhendo Ação ou cancelando; sem perfis de visibilidade.
- **Freeze 05/11 vs 07/11** resolvido: 05/11 freeze funcional, 07/11 submetível, 08/11 submissão.
- **Edital verificado** (research-edital.md): critérios do júri e nominações Experts/Community separadas; pesos de voto não publicados (Q-11). Q5 da intenção está tratada.
- **Novos itens vindos do edital:** [NOTE FOR PM] sobre construção a partir de 26/10 (Q-1), originalidade do SentaiTask (Q-2), artigo técnico como P1, NFR-11 (x64/ARM64), fine-tuning fora de escopo.
- **Item novo do PRD:** FR-13 (teste de instrução embutida) concretiza o invariante "mensagens são dados hostis".

---

## 3. Itens cobertos (resumo)

- **Tese e objetivo:** §1 e §2; invariantes de governança em §6, FR-13, FR-21, NFR-7, NFR-8; agente sem estado em memória (addendum A).
- **Cenários sujos e regras ingênuas:** FR-31 e addendum E cobrem P2, P3, P5, P8, P9 e P1 com regra ingênua e desfecho correto.
- **Contrato D1–D7:** D1 no Glossário; D4 no addendum C; D5 em FR-6, FR-12 e FR-35; D6 em FR-5 e addendum D; D7 em FR-8. (Ressalvas em G7, G8, G14, G16.)
- **Ciclo de vida:** Incidente (FR-25 a FR-27), Revalidação (FR-20, FR-18), dedup/ResolvedByPriorReceipt (FR-24, FR-23).
- **JTBD dos avaliadores:** §2.1, quase literal.
- **Espinha e 6 momentos da demo:** §10 e addendum F (ressalvas em G2, G3, G17).
- **NFRs numéricos:** NFR-1 a NFR-4 iguais à intenção, marcados como suposição.
- **Marcos e cortes:** §9.4 (resumido; ver G1, G13).
- **Fora de escopo:** §8 e §9.3 cobrem System 1, HL7/FHIR, busca semântica, multiprovedor, canvas, P4, P7, ações fora do catálogo, inferência clínica (falta P10/P12, G18).
- **Insights da síntese:** addendum G e §4.8 (Dossiê P0), §4.9 (simulador como prova da tese).
- **Starbursting (pendências da §10.10):** TTL (FR-18), critério de resolvido = Recibo (FR-2), payload original vs transformado (addendum C), concorrência (Q-9), reconstrução após reinício (FR-4), divergência Production × Nexus (Q-10), resolução de REQUEST_REVIEW (FR-29), replay vs real (FR-38, FR-41), perfis de visibilidade (§8). Ficaram sem cobertura: dono do Caso (G12), HOLD na fila IRIS (G10), equivalência de recibos (G9).
- **Risco do build 154:** Q-12 e o marco de 25/10.

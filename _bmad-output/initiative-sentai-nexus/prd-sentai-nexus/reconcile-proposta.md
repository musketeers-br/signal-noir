# Reconciliação: proposta Musketeers (16/10) × PRD + addendum

**Fonte:** `/Users/henryhamon/Downloads/Sentai-Nexus-proposta-Musketeers.pdf` (7 páginas, "Proposta final para alinhamento da equipe", 16/10/2026)
**Alvo:** `prd-sentai-nexus.md` e `addendum.md` (nesta pasta)
**Data:** 18/10/2026. O PRD não foi editado.

Convenção: "p.N" é a página da proposta. "§" é a seção do PRD. "Add." é o addendum.

---

## 1. Lacunas

### G-1. A demo perdeu os momentos "Limite" e "Resiliência" (alta)
- **Fonte:** p.7, roteiro de ~4 min: "5 / Limite: segundo pedido com identidade ambígua permanece em revisão" e "6 / Resiliência: repetição da aprovação não produz efeito duplicado".
- **PRD:** §10 e Add. F. Nenhum dos seis (ou oito) momentos mostra um Caso indo para revisão (Dossiê / identidade ambígua). Nenhum mostra a aprovação repetida sem efeito duplicado. A aprovação dupla aparece só como caso de borda de UJ-1, fora do roteiro.
- **Por que importa:** a abertura foi redesenhada de propósito, mas os dois momentos que caíram são justamente os que provam os controles que o próprio PRD diz que o júri quer ver (§2.1: "aprovação, idempotência e rastreabilidade sérias"). Também provam o fail-safe, que o Add. G chama de "vitória mais barata". A troca pela abertura nova não exigia retirar esses momentos.
- **Correção sugerida:** no §10, reintroduzir (a) um flash do Dossiê de Revisão (identidade ambígua, UJ-4) e (b) um duplo clique em "Aprovar" com um único Recibo. Podem entrar junto do momento 4 ou do 5. Ajustar o Add. F.

### G-2. A estratégia de avaliação ficou mais fraca: separação, calibração e terceiro braço (alta)
- **Fonte:** p.6, "Comparação e métricas":
  - comparar **três** braços: regras; regras + agente; regras + agente + System 1;
  - "Separar treino, calibração e teste por famílias de casos, parceiros e padrões de falha; não apenas por nomes diferentes em mensagens semelhantes";
  - se o modelo controlar decisões, "avaliar calibração e relação entre cobertura automática e erro".
- **PRD:** FR-32 reserva "parte das variantes" de **cada Família** como teste, ou seja, a divisão é dentro da Família. FR-39 e SM-C2 citam só "ajuste" e "teste". Não há conjunto de calibração, nem holdout por Parceiro ou por padrão de falha. Calibração da Confiança (ALTA/MEDIA/BAIXA) e a curva cobertura × erro estão ausentes. O Benchmark tem só dois modos.
- **Por que importa:** a proposta pede que a separação seja por estrutura (família, parceiro, padrão), e não por superfície. A divisão por variantes dentro da mesma Família é exatamente o "nomes diferentes em mensagens semelhantes" que a proposta rejeita, e isso enfraquece a SM-1. A Confiança é usada como roteadora (FR-15) sem nenhuma métrica de calibração.
- **Correção sugerida:**
  - Em FR-32/FR-39, exigir que o conjunto de teste contenha Parceiros e padrões de falha (e, se possível, uma Família) ausentes do ajuste.
  - Adicionar métrica de calibração da Confiança: acerto por nível ALTA/MEDIA/BAIXA.
  - Adicionar a curva cobertura automática × erro como métrica secundária.
  - Registrar o terceiro braço (System 1) como condicional em §9.3, com o protocolo descrito.

### G-3. O experimento do System 1 foi reduzido a uma linha (média)
- **Fonte:** p.2 (nota do diagrama) e p.6, "System 1: extensão opcional":
  - modo sombra **sem autorização nem efeito externo**;
  - **no máximo um** modelo, adicionado só depois dos P0 estáveis;
  - Laya como candidato quando a execução local importar, ou uma API hospedada;
  - pergunta do experimento: "O modelo melhora a triagem ou reduz custo sem aumentar erros operacionais?";
  - "Sem benefício demonstrado, ou com impacto no prazo, a extensão fica fora".
  - N12 (P2): "Previsões comparadas sem controlar execução".
- **PRD:** §9.3 diz apenas "só entra se provar ganho no Benchmark sem afetar o P0". Ficaram de fora a pergunta, o critério "sem aumentar erros operacionais", a restrição "sem autorização/efeito externo", o limite de um modelo e os candidatos.
- **Correção sugerida:** acrescentar em §9.3 (ou no addendum) um bloco de 4 linhas com a pergunta, as restrições e o critério de saída. Se o recuo de P2 para "fora da submissão" for intencional, deixar isso explícito.

### G-4. Não há seção de riscos (média-alta)
- **Fonte:** p.6, "Riscos e resposta prevista", com cinco riscos:
  1. mudança ou incompatibilidade no EAP → fixar o build 154, provar cedo e **registrar as APIs usadas**;
  2. falha ou lentidão do provedor → limites, revisão segura e replay identificado;
  3. decisão incorreta ou instrução no payload → ferramentas restritas, evidências e validação determinística;
  4. efeito duplicado após timeout → chave, recibo e reconciliação;
  5. **capacidade menor que a prevista → cortar P1/P2 e reduzir a amplitude do cenário**.
- **PRD:** não há seção de riscos. Os riscos 2 a 4 estão cobertos indiretamente (NFR-8, FR-13, FR-22/23) e o risco 1 aparece em parte (Q-12, marco de 25/10). Estão ausentes "registrar APIs usadas" e o risco 5, que é tratado só pelos cortes por data em §9.4.
- **Correção sugerida:** adicionar §"Riscos" com os cinco riscos e um ponteiro para o FR/NFR que mitiga cada um. Incluir o risco de escopo descrito em G-5.

### G-5. O escopo P0 cresceu sem que a capacidade fosse reconciliada (média-alta)
- **Fonte:** p.1, recorte do MVP: quatro situações simples. p.5: "Pressupõe três pessoas com disponibilidade recorrente". p.6: o risco de capacidade se responde reduzindo a amplitude do cenário.
- **PRD:** §9.1 coloca no P0 os Cenários limpos **e** as Famílias sujas P3, P5 (com P1), P8 e P9, com ≥ 5 variantes cada e divisão ajuste/teste (FR-32), além do Dossiê (§4.8) e da Revalidação. A janela de construção também encolheu para 26/10–08/11 (Q-1). A premissa de capacidade não aparece.
- **Por que importa:** é uma mudança intencional vinda do brainstorming. Mesmo assim, o PRD não registra que ela inverte a resposta prevista ao risco de capacidade nem que ocupa uma janela menor. O corte de 05/11 para 3 Famílias chega tarde.
- **Correção sugerida:**
  - Registrar a premissa de capacidade (3 pessoas, disponibilidade recorrente).
  - Antecipar para 29/10 a decisão de quantas Famílias e variantes entram no P0.
  - Declarar o "mínimo submetível" quanto à amplitude de Cenários, por exemplo P5/P8 + P9 + um limpo.

### G-6. Responsabilidade e revisão cruzada foram omitidas (média)
- **Fonte:** p.6: "Cada entrega tem um responsável e revisão de outro Musketeer". "Henry mantém o simulador e o conjunto de testes com contrato definido junto à frente IRIS". "Segurança de execução, retomada e idempotência recebem revisão conjunta". p.5: condução por período (José conduz a prova técnica; Henry valida cenários; Henry testa falhas; Henry coordena a submissão). Escopo de Henrique: "eventos e tratamento visual das falhas". Escopo de Henry: "critérios de aceite, roteiro, registro".
- **PRD:** §9.4 "Frentes" mantém as três frentes e o contrato de Cenários. Ficaram de fora a revisão por outro integrante, a revisão conjunta de execução/retomada/idempotência e a condução por período. O §4.8 (Dossiê) não tem frente atribuída: José cobre §4.1–4.7, Henrique §4.10 e Henry §4.9/4.11/4.12.
- **Correção sugerida:**
  - Acrescentar em §9.4 a regra "responsável + revisor" e a revisão conjunta de FR-17 a FR-24.
  - Atribuir o §4.8: o backend vai para José e a apresentação para Henrique.
  - Opcionalmente, adicionar uma coluna "Condução" à tabela de marcos.

### G-7. A definição de pronto não está consolidada (média-baixa)
- **Fonte:** p.7, "A submissão estará pronta quando", com sete itens.
- **PRD:** todos os itens têm FR/NFR correspondente (FR-42/SM-4, FR-9, FR-15, FR-4/FR-19, FR-22/23/NFR-6, FR-40, FR-43/FR-38), mas espalhados. Não existe um checklist de pronto. O critério de saída de 07/11 diz só "instalação cruzada, vídeo, README".
- **Correção sugerida:** transformar o critério de 07/11 em §9.4 numa DoD de sete itens, com referência aos FRs.

### G-8. Faltam fases do cronograma e a margem (baixa-média)
- **Fonte:** p.5:
  - "09–15/11: Correções e acompanhamento da votação. Todos; preservar estabilidade";
  - "08/11 fica como margem operacional";
  - "08/11 Conferência e submissão — Henry coordena";
  - 06–07/11 inclui o **artigo**.
- **PRD:** §9.4 termina em 08/11. Não há fase pós-submissão nem diretriz de estabilidade durante a votação. Não está explícito que 08/11 é margem, nem quem coordena. A política de alterações durante a votação também não aparece (o PRD não diz se o edital permite).
- **Correção sugerida:**
  - Adicionar a linha "09–15/11: correções permitidas pelo edital, sem mudanças funcionais; acompanhar a votação".
  - Marcar 08/11 como margem.
  - Abrir uma questão em §12 sobre o que pode mudar depois da submissão.

### G-9. N09 "registro" e N11 "arquitetura" sumiram dos critérios (baixa)
- **Fonte:** p.4. N09 inclui "registro" (inscrição/publicação da submissão), também listado entre as entregas de Henry (p.6). N11 menciona "Arquitetura, experiência com AI Hub e resultados".
- **PRD:** FR-42 a FR-45 não falam do registro ou publicação da submissão (Open Exchange/formulário). FR-46 não cita arquitetura.
- **Correção sugerida:** criar FR-47, "Registro da submissão" (publicação no Open Exchange e inscrição no concurso até 08/11), e incluir "arquitetura" em FR-46.

### G-10. A prioridade de métricas é inconsistente (N10) (baixa-média)
- **Fonte:** p.4. N10/P1: "Duração, tentativas, tokens e custo estimado por caso".
- **PRD:** §9.2 deixa "Métricas e exportação completas" como condicional. Já NFR-9, FR-35 e FR-9 exigem modelo, duração, tokens e custo por Caso no P0, e §10 mostra custo na demo. O texto não define o que é "completas".
- **Correção sugerida:** separar em "métricas por Caso visíveis (P0)" e "export/relatório agregado (P1)", ou outra divisão explícita.

### G-11. A métrica "custo por caso resolvido" virou "custo por Caso" no relatório (baixa)
- **Fonte:** p.6: "custo por caso resolvido".
- **PRD:** NFR-4 usa "por Caso resolvido", mas FR-39 diz "custo estimado por Caso". "Revisão humana" como taxa medida aparece só como contramétrica (SM-C1), e o relatório não exige a taxa por braço.
- **Correção sugerida:** em FR-39, usar "custo por Caso resolvido corretamente" e incluir a "taxa de revisão humana" por modo.

### G-12. Exclusões menores perdidas (baixa)
- **Fonte:** p.1 exclui "múltiplos protocolos/**agentes**". p.3: "agendamentos e administração de servidores só entram se necessários à demonstração".
- **PRD:** §8/§9.3 não citam múltiplos agentes, agendamentos nem administração de servidores.
- **Correção sugerida:** acrescentar as duas exclusões em §9.3.

### G-13. A nomenclatura P1/P2 colide (baixa, introduzida pelo PRD)
- A proposta usa P0/P1/P2 para **prioridade** do backlog. O PRD usa P1–P11 para **Famílias de Cenários** e também "P1" como prioridade (§9.2, FR-46). "P1" chega a significar duas coisas diferentes (multicausal × prioridade).
- **Correção sugerida:** renomear as Famílias (por exemplo F2, F3, F5…) ou as prioridades.

### G-14. O registro de qualidade foi deslocado (baixa)
- **Fonte:** p.7. O diferencial proposto é "a resolução verificável de exceções, apoiada nos controles operacionais já desenvolvidos no SentaiTask". O tom é contido: "Este documento não registra testes de execução ou ganhos já medidos".
- **PRD:** §1 mantém a frase, mas desloca o enquadramento para "agente supera regras no mundo sujo". Também introduz metas numéricas (SM-1: ≥ 80% × ≤ 40%) que a proposta evitava. Elas estão marcadas `[ASSUMPTION]`, mas viram critério de sucesso primário.
- **Correção sugerida:** manter a verificabilidade/controles como diferencial principal e o mundo sujo como prova. Rotular SM-1 explicitamente como hipótese a confirmar, e não como meta de entrega. Garantir que README e vídeo não afirmem ganhos não medidos.

---

## 2. Mudanças intencionais observadas

- **Abertura da demo redesenhada:** "código desconhecido → mapeamento" sai da abertura e fica como contraste limpo ou fallback (§10, Add. F).
- **Incidentes/P2 rebaixados para condicional** (§9.2) e primeiro corte (§4.7). Não existiam na proposta.
- **Tese do mundo sujo:** Famílias P1/P3/P5/P8/P9, variantes, gabarito e Benchmark limpo × sujo (§4.9, §4.11). É uma expansão vinda do brainstorming.
- **Janela de construção:** 26/10–08/11 em vez de 16/10, e a prova de 16–25/10 passa a ser *spike* (NOTE em §9.4, Q-1). Vem do edital.
- **Originalidade do reaproveitamento do SentaiTask** posta em dúvida (Q-2). A proposta assumia o reaproveitamento.
- **Novos conceitos:** Fase, Incidente, Escopo `batch`, Confiança, Dossiê de Revisão, Revalidação explícita com `Held`/`Cancelled`, `ResolvedByPriorReceipt`, Replay.
- **N13 (HL7/FHIR, P2)** movido para v2, fora da submissão (§9.3). O rebaixamento não está explicado; vale uma linha de justificativa.
- **N12 (System 1, P2)** movido para fora da submissão (§9.3). Ver G-3.
- **Marco de 29/10** endurecido ("≥ 1 Cenário sujo") e corte ampliado para incluir P2 e refinamentos visuais. O "protocolo adicional" saiu porque já estava fora.
- **Metas numéricas** de latência, custo e instalação (NFR-2 a NFR-4, NFR-10) e de acurácia (SM-1), todas marcadas como suposição.

---

## 3. Itens totalmente cobertos (resumo)

- **Proposta e objetivo** (p.1): §1 e FR-9. Usuário operador, pedidos laboratoriais sintéticos JSON, parceiro HTTP, sem decisão clínica (§2, §6, §8).
- **As quatro situações do MVP** (p.1): Cenários limpos FR-30, com FR-14 (mapeamento aprovado), FR-15 (identidade → revisão), FR-24/clean (já processado), Política de tentativas/`Failed`.
- **Ações** RETRY, APPLY_APPROVED_MAPPING, REQUEST_REVIEW e HOLD (Glossário). Exclusões principais: editor de Productions, geração de código, correção livre, fine-tuning, vários provedores (§8, §9.3).
- **Arquitetura** (p.2): componentes e namespace `Nexus` (Add. A). Validar a integração no build 154 antes de consolidar interfaces (Add. A, marco de 25/10). Production como dona do estado (§4.1).
- **Reaproveitamento do SentaiTask** (p.3): a tabela foi integralmente transposta para Add. B. Fronteira WQM/WaveDispatcher em Add. A.
- **Controles obrigatórios** (p.3), todos os sete: FR-14, FR-10/11/NFR-1, FR-9/Glossário (versões), FR-17/18/20, FR-19/22/23, FR-21/FR-7, FR-12/FR-13/NFR-8. A explicação verificável está em FR-6/FR-35. "Sem objeto de agente em memória como único estado" está em Add. A.
- **Backlog N01–N09** (P0): N01 → FR-9/FR-42/marco 25/10; N02 → FR-1/FR-2; N03 → FR-10/FR-12; N04 → FR-14; N05 → FR-4/FR-19; N06 → FR-22/FR-23; N07 → FR-34/FR-35; N08 → FR-39; N09 → FR-42/43/45 (exceto "registro", G-9). **N11** → FR-46 (exceto "arquitetura").
- **Sequência de implementação** e interface com dados de contrato até 29/10 (§4.10, §9.4).
- **Regra de corte** transcrita literalmente (§9.3). Marcos de corte de 25/10, 02/11 e 05/11 preservados, alguns mais detalhados (§9.4).
- **Métricas:** resolução correta, ações indevidas, latência p50/p95 e duplicações (FR-39, NFR-2/3/6, SM-3).
- **Demo:** mostrar modelo, duração, tentativas e custo; Visual Trace; identificar sintético e replay (§10, FR-37/38).
- **Datas do edital:** submissão 08/11 e votação até 15/11; build 154 (§1, §7).

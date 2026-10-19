# Revisão adversarial: PRD Sentai Nexus

Data: 2026-10-18. Escopo: `prd-signal-noir.md` e `addendum.md`, com `research-edital.md` como referência de regras. O PRD não foi editado.

## Veredito

O PRD é bem escrito e honesto na intenção, mas **promete um produto de seis semanas em 14 dias** e, pior, **o Benchmark que sustenta a tese está inclinado por construção**: duas das cinco Famílias sujas (P2 e P3) medem a plataforma, não o agente, e a linha de base "Regras" é uma regra de palha escrita pelo mesmo time que escreve o Simulador e o gabarito. Um jurado InterSystems atento derruba a tese "empata no limpo, diferencia no sujo" em uma pergunta: *"o seu modo Regras passa pela mesma Revalidação?"*. Se passa, P3 empata. Se não passa, o benchmark foi armado.

Contagem: **5 críticos, 6 altos, 9 médios, 4 baixos.**

---

## CRÍTICO

### C1. P2 e P3 não diferenciam o agente: o Benchmark mede a plataforma e credita ao LLM
- **Onde:** FR-31, FR-20, FR-25/26, addendum §E (linhas P2 e P3), SM-1, §10 momento 5.
- **Por que importa:** a Revalidação (FR-20) é determinística e roda no servidor para *toda* Proposta (§4.4: "seja do Agente, do modo Regras ou do Operador"). Logo, em P3 o modo Regras também é bloqueado e vai para `Held`/`Cancelled`. A "regra ingênua" do addendum ("executa com o snapshot") só perde se o modo Regras **pular** a Revalidação, ou seja, se o baseline for deliberadamente aleijado. O mesmo vale para P2: a detecção de Incidente é "pelo sistema" ([ASSUMPTION] em §4.7), e a contribuição do agente é propor `HOLD batch`, coisa que a regra `incidente ativo → HOLD` faz em uma linha. Contar P2 e P3 no placar "Regras vs Regras + Agente" é exatamente o que a comunidade vai chamar de benchmark armado. O próprio addendum §G admite: "A Revalidação (P3) sai quase de graça dos controles herdados". Sai de graça para os dois modos.
- **Correção:** separar o relatório em duas tabelas: (a) **Decisão do agente** (P5, P8, P9, P1) com comparação Regras vs Agente; (b) **Garantias da plataforma** (P3, idempotência, Reconciliação, P2) mostradas como invariantes que valem para qualquer autor de Proposta, sem placar comparativo. Isso é mais forte para o júri (Complexity), e é honesto. Na demo, o P3 vira "a aplicação governa, mesmo quando o humano aprovou", não "o agente ganhou".

### C2. A linha de base "Regras" é de palha, e o modo "Regras + Agente" não está definido
- **Onde:** FR-31 ("regra ingênua documentada"), FR-30, FR-39, SM-1, SM-2, addendum §E coluna "Regra ingênua".
- **Por que importa:**
  - Cada regra ingênua usa **um só sinal** (`5xx → RETRY`, `200 → sucesso`, "aplica o 1º mapeamento", "código válido → RETRY"). Qualquer integrador sênior escreve `if body contém "validation" → REQUEST_REVIEW` ou consulta Recibos antes de reenviar. O time desenha o mundo, escreve a regra que perde nele e escreve o gabarito. Três papéis, um autor, zero independência.
  - SM-2 ("empate no limpo prova que não inclinamos") é falso como argumento: o mundo limpo é trivial por definição, então empatar nele não diz nada sobre o mundo sujo. É um álibi, não um controle.
  - O PRD nunca define o que é **"Regras + Agente"**. O agente roda sempre? Só quando as regras não casam? Se for "só no fallthrough", o empate no limpo é garantido por construção (o agente nem é chamado), e o SM-2 vira tautologia. Se roda sempre, o custo e a latência do limpo precisam aparecer.
- **Correção:**
  - Definir o modo Regras como **"melhor baseline razoável"**: regras com acesso às mesmas Ferramentas (lê o corpo, consulta Recibos, consulta healthcheck), escritas por quem **não** viu as variantes de teste (José escreve as regras; Henry escreve as variantes de teste depois).
  - Publicar no relatório as regras completas, em código, e pelo menos **uma variante em que o agente perde ou empata** no sujo. Um benchmark sem derrota não convence experts.
  - Definir explicitamente o modo combinado (proposta: regras decidem quando há casamento de alta precisão; agente roda no resto; o relatório mostra quantas vezes cada um decidiu).
  - Trocar SM-2 por: "as regras do baseline acertam ≥ X% nos sujos *quando aprimoradas com um sinal extra*", mostrando quanto custa, em regras, cobrir cada Família. Esse é o argumento real: o agente generaliza sem uma regra por variante.

### C3. Não determinismo do LLM + chave e modelo do jurado são incompatíveis com metas pontuais como "≥ 80% contra ≤ 40%"
- **Onde:** SM-1, FR-32, FR-40, NFR-2 a NFR-4, Q-3 (aberta), §10 momento 6.
- **Por que importa:**
  - Com "mínimo de 5 variantes" por Família e "parte reservada como teste", o conjunto de teste tem 1 a 2 variantes por Família, uns 6 a 10 Casos no total. 80% de 2 é "acertou 2 de 2". Isso é anedota, o mesmo pecado que o addendum §G condena ("um placar de um caso por Cenário é anedota").
  - O jurado usa a **própria chave** e, se Q-3 não for travada, possivelmente **outro provedor e modelo**. Tool calling, formato de saída estruturada e latência variam muito entre provedores. O placar do vídeo não vai se reproduzir, e FR-40 só pede que a diferença seja "declarada". Declarar não salva: um jurado que roda e vê o agente propor `RETRY` no P5 conclui que o vídeo é editado.
  - Temperatura 0 não garante determinismo em nenhum dos provedores suportados.
- **Correção:**
  - Travar **um provedor e um modelo padrão** no README (Q-3 deixa de ser questão aberta e vira decisão até 27/10), com o modelo alternativo marcado como "não validado".
  - Rodar cada variante de teste **k = 3 a 5 vezes** e reportar média e dispersão por Família. Meta expressa como faixa, não ponto.
  - Separar dois comandos: `validate` (smoke ao vivo de 3 Casos, barato, < 2 min) e `benchmark` (completo, com custo estimado mostrado **antes** de rodar e confirmação). Distribuir o resultado de referência gravado (Replay) como baseline comparável.
  - Subir o número de variantes de teste para pelo menos 4 por Família nas Famílias que ficarem (P5, P8, P9), gerando por parâmetro em vez de escrever à mão.

### C4. O escopo P0 não cabe em 3 pessoas e 14 dias corridos
- **Onde:** §9.1 inteiro, §4 (46 FRs), §3 (13 estados), addendum §D (~20 transições), §9.4.
- **Por que importa:** o P0 inclui, ao mesmo tempo: Production com BS/BP/BO; Caso persistente com Fases, Evidências imutáveis, Propostas versionadas, Aprovações com expiração, Execuções, Recibos e Linha do Tempo append-only; integração com um build EAP de agente ainda não provado; Validador com evidência mínima por Ação (Q-8 aberta); Revalidação; idempotência; Reconciliação; retomada após reinício; Dossiê; UI em tempo real com navegação afirmação → evidência e evidências lado a lado; Simulador com sementes, quatro Famílias sujas, cinco Cenários limpos, 5+ variantes cada (são **45+ variantes** com gabarito); Benchmark com p50/p95 e custo; Replay; README; vídeo; instalação cruzada x64 e ARM64. Conta honesta: cada uma dessas linhas é de 1 a 3 dias para uma pessoa. A soma passa de 40 pessoa-dia, contra uns 35 a 40 pessoa-dia disponíveis (3 × 13, *se* ninguém tiver emprego, e o vídeo e a submissão levam os dois últimos dias). Não sobra margem para o build 154 se comportar mal, que é o cenário mais provável num EAP.
- **Correção (cortes concretos, em ordem):**
  1. **Fases (FR-3 "nova Fase")**: cortar. Nova Exceção do mesmo Pedido vira evento na Linha do Tempo e nova Tentativa. Economiza transições, UI e testes.
  2. **Incidentes / P2**: tirar do P0 e do P1. Mostrar no máximo como slide de roadmap. (Ver H4.)
  3. **Expiração de Aprovação por "Evidência relevante muda"** (FR-18): ficar só com prazo fixo.
  4. **Replay** (FR-41): só como arquivo de resultado de referência, sem modo de execução na UI.
  5. **Estados**: colapsar `DecisionProposed` (transitório, ninguém vê) e `Approved` (idem). Ver H1.
  6. **Variantes**: 3 Famílias (P5, P8, P9) × parâmetros gerados, em vez de 5 Famílias escritas à mão.
  7. **Artigo**: só depois da submissão (pode entrar durante a votação, o edital permite melhorias).
  8. **NFR-11 ARM64**: testar no x64 e declarar ARM64 como "deve funcionar", a não ser que alguém do time use Mac M-series como máquina diária.

### C5. O caminho crítico depende de um EAP não provado, e o marco que o prova cai fora da janela de construção
- **Onde:** §9.4 marco 25/10, [NOTE FOR PM], Q-1, Q-12.
- **Por que importa:** o marco de 25/10 exige que "o componente da Production chama de verdade o AI Hub build 154" e que a Proposta "fica persistida e sobrevive a reinício". Isso é código de submissão escrito **antes de 26/10**, e o edital diz que o app deve ser construído durante o concurso. O próprio PRD reconhece o conflito numa nota e o deixa em aberto. Ou o spike é descartado (e a prova não serve de base), ou é reaproveitado (e a submissão fica exposta a desclassificação, já que "a decisão do júri é final, inclusive sobre a admissão"). Além disso, se o build 154 não permitir o agente com tool calling dentro de uma Business Operation do jeito desenhado (Q-12), **todo** o §4.3 cai, e não há plano B escrito.
- **Correção:**
  - Reescrever o marco de 25/10 como **spike descartável em repositório separado**, cujo único artefato herdado é um documento: "o que funciona no 154" (API de invocação, formato de tool, como capturar tokens, como aparece no Visual Trace).
  - Criar o repositório da submissão em 26/10, com commit inicial datado.
  - Escrever o **plano B** agora: se o agente do AI Hub não fizer tool calling dentro da BO, as Ferramentas são pré-coletadas pela Production (fan-out determinístico) e o agente decide sobre um pacote de Evidências numa única chamada. Perde "investigação iterativa", mantém "decisão dentro do workflow", que é o requisito do edital.
  - Perguntar no Discord até 26/10 (Q-1), por escrito, e colar a resposta no README.

---

## ALTO

### H1. A máquina de estados se contradiz em pelo menos seis pontos
- **Onde:** §3 Estados, FR-5, FR-16, FR-18, FR-26, addendum §D.
- **Por que importa:** FR-5 promete recusar transições não permitidas, mas a tabela que define "permitidas" está incoerente:
  1. `HOLD single_case` não exige Aprovação (FR-16), então segue `DecisionProposed → Executing`. Mas o efeito de `HOLD` é `Held`, e não existe `Executing → Held`. Também não existe `DecisionProposed → Held`.
  2. `REQUEST_REVIEW` é uma Ação do Catálogo, mas nenhuma transição diz para onde vai uma Proposta `REQUEST_REVIEW` aceita.
  3. FR-18 diz que Aprovação expirada "volta para Revalidação"; o addendum diz `Approved → PendingApproval`. São coisas diferentes.
  4. "qualquer não terminal → Investigating (nova Fase)" contradiz FR-26 (Caso em Incidente ativo não abre Investigação individual) e quebra `Executing`: a falha da própria Tentativa de Execução é uma "nova Exceção do mesmo Pedido". Ela reinicia a Investigação no meio da Execução ou segue a Política de Tentativas até `Failed`? As duas regras valem ao mesmo tempo.
  5. `Executing` após timeout, com Reconciliação **sem** Recibo: não há transição. É o caso mais comum de rede.
  6. `Rejected → Investigating` não tem limite: negar sempre gera loop de Investigações pagas pela chave do jurado.
- **Correção:** reduzir para 9 estados (`Open`, `Investigating`, `PendingApproval`, `Executing`, `Held`, `ReviewRequired`, `Resolved`, `Cancelled`, `Failed`, com `ResolvedByPriorReceipt` como *motivo* de `Resolved`). Escrever a tabela completa (estado × evento) antes da arquitetura, com um teste por célula. Regra explícita: Exceção durante `Executing` é Tentativa, não Fase. Limite de 1 reinvestigação após negação, depois `ReviewRequired`.

### H2. `ResolvedByPriorReceipt` fecha o Caso sem Validador, e o P9 tem risco clínico real
- **Onde:** FR-24, addendum §D (`Investigating → ResolvedByPriorReceipt`), addendum §E (P9), UJ-3, §6 ("Nenhuma decisão clínica").
- **Por que importa:**
  - A transição sai direto de `Investigating`, ou seja, a **afirmação do agente** encerra o Caso. Não há Ação no Catálogo para isso, e não há verificação determinística. Isso contradiz o princípio central do produto ("A IA propõe e a aplicação governa") justamente no momento 3 da demo.
  - O P9 casa por "Pedido recente do mesmo paciente sintético com outro ID de transação". No mundo real, dois pedidos do mesmo paciente em 3 minutos podem ser **dois exames legítimos**. Encerrar um deles como "já entregue" é suprimir um pedido laboratorial. O PRD diz que não toma decisão clínica, mas esse desfecho tem efeito clínico. Um jurado da área de saúde da InterSystems vai notar.
- **Correção:** criar a Ação `LINK_PRIOR_RECEIPT(receiptId)` no Catálogo. O Validador confirma deterministicamente que o Recibo existe e que o conteúdo do pedido anterior é **equivalente** ao atual (mesmo exame, mesma amostra, mesma unidade). O gabarito do P9 inclui variantes em que o pedido anterior é parecido mas **não** equivalente, com resposta correta `RETRY` ou `REQUEST_REVIEW`. Isso também ajuda a desarmar C2: o agente precisa distinguir, não só buscar.

### H3. Concorrência, durabilidade e espera humana dentro de uma Production IRIS são o maior iceberg do PRD, e foram empurrados para a arquitetura
- **Onde:** FR-4, FR-7, FR-17, FR-19, FR-21, FR-22, Q-9, Q-10.
- **Por que importa:** o PRD promete como "testável" coisas que dependem de um mecanismo que ele declara não definido (Q-9). Na prática:
  - A Aprovação chega pela REST/SSE da UI, fora da Production. Ela precisa acordar um Business Process que está esperando um humano por até 15 min. Em BPL isso significa resposta diferida, alarmes ou Workflow do Ensemble, e cada um tem comportamento próprio em reinício.
  - "Dois Operadores aprovam a mesma versão → no máximo uma Execução" exige trava ou versão otimista no registro do Caso, verificada na mesma transação que grava a autorização (FR-21).
  - FR-7 ("ordem real mesmo assíncrona") exige um `seq` monotônico por Caso, gerado num único lugar.
  - Q-10 (estado da Production × estado do Caso) não é questão de arquitetura, é decisão de produto: alguém tem de ser a fonte da verdade.
- **Correção:** decidir já, no PRD: **o Caso persistente é a fonte da verdade; os BPs são curtos e sem estado** (um por passo: investigar, validar, executar), disparados por mudança de estado. Aprovação = `UPDATE` condicional (`WHERE state='PendingApproval' AND proposalVersion=?`) que grava a autorização e enfileira a Execução na mesma transação. A idempotência fica garantida por essa linha de banco, não por lógica distribuída. Isso transforma FR-19/FR-22 em um teste de unidade.

### H4. FR-26 ("1 Investigação, não N") é impossível com detecção por limiar, e conflita com a latência
- **Onde:** FR-25, FR-26, SM-7, NFR-2, Q-6.
- **Por que importa:** o Incidente nasce quando o número de Exceções numa janela passa de um limiar. Até lá, as primeiras `limiar − 1` Exceções já abriram Casos e, pela regra normal, já dispararam Investigações individuais. Para garantir "1, não N", o sistema teria de **segurar toda Investigação** até a janela fechar (minutos), o que destrói o NFR-2 (p50 de 18 s) para todos os Casos, inclusive os que não são rajada. Além disso, Casos já em `PendingApproval` quando o Incidente se forma não têm destino definido.
- **Correção:** cortar P2 da submissão (já é a primeira funcionalidade no §9 a sair; corte agora e libere o tempo). Se o time insistir: trocar a meta para "Investigações ≤ limiar + 1" e debounce curto por Parceiro (ex.: 10 s), com Casos em andamento absorvidos só no próximo passo. E nunca mostrar P2 no placar comparativo (ver C1).

### H5. O gabarito e a pontuação permitem que "sempre pedir revisão" pareça seguro, e não há regra de desempate
- **Onde:** FR-33, SM-1, SM-5, SM-C1, addendum §E (P1: "Mapeamento aplicável **ou** revisão"; P5: "mapeamento **ou** revisão").
- **Por que importa:** com "Ações aceitáveis" múltiplas e três classes (correto, revisão segura, incorreto), não está escrito se `REQUEST_REVIEW` conta como acerto no SM-1. Se conta, um agente covarde empata com um agente bom. Se não conta, a SM-C1 ("não minimizar revisão") fica sem efeito. Também não há definição de "correto" quando a Ação está certa e o parâmetro errado (mapeamento A em vez de B no P8), nem quando o desfecho certo é atingido por Diagnóstico errado.
- **Correção:** uma matriz de pontuação explícita por variante: `ação ótima` = 1, `revisão aceitável` = 0,5 (só onde o gabarito marcar), `revisão desnecessária` = 0, `ação com efeito errado` = −1. Reportar também "taxa de efeito indevido" separada. Exigir que o Diagnóstico cite a Evidência-chave da variante (checagem por ID) para contar como 1.

### H6. O júri vê 4 minutos e um README; o PRD gasta energia no que ninguém vai ver
- **Onde:** §10, addendum §F, FR-45, FR-35, FR-28, FR-18.
- **Por que importa:** o roteiro tem 6 momentos em ~240 s, ou 40 s cada. Cada momento ao vivo envolve uma Investigação com meta de p50 de 18 s, e com Aprovação até 35 s (NFR-3). Não cabe sem cortes de edição, e cortes de edição num vídeo de LLM levantam suspeita. Ao mesmo tempo, o PRD investe em coisas invisíveis em 4 minutos: Fases, expiração por mudança de Evidência, retomada de `Investigating` após reinício, p95, orçamento de 20 s. O que o jurado realmente julga: (1) o README funciona da primeira vez? (2) aparece o AI Hub no Visual Trace? (3) há um momento "uau" claro? (4) a UI parece produto ou protótipo?
- **Correção:** 3 momentos, não 6: **P5/P8** (a superfície mente, o agente lê o corpo, ~70 s), **P9 com variante não equivalente** (o agente distingue duplicata de pedido legítimo, ~60 s), **garantias da plataforma** (clique duplo, P3, reinício, numa montagem de 40 s), e 30 s de placar com faixa de dispersão. Gravar em velocidade real e acelerar visivelmente (indicador "2×") em vez de cortar. Priorizar no backlog: README + `validate` > Visual Trace > UI do Caso > o resto.

---

## MÉDIO

### M1. NFR-1 (≤ 4 Chamadas de Ferramenta) contradiz SM-C3 e o próprio roteiro
- **Onde:** NFR-1, SM-C3, UJ-1, UJ-3, addendum §F momento 3 ("P9 com P1").
- A UJ-1 já usa corpo da resposta, healthcheck, histórico e Política/Mapeamento: são 4. UJ-3 precisa ainda de Recibos e Pedidos recentes. "P9 com P1" passa de 4. SM-C3 diz para não cortar Chamadas necessárias; NFR-1 obriga a cortar.
- **Correção:** orçamento de 6 a 8 chamadas e 30 s, ou Ferramentas mais gordas (ex.: `get_case_context` devolve falha + histórico + saúde numa chamada). Medir no spike antes de fixar.

### M2. FR-13 (prompt injection) é tautológico como escrito
- **Onde:** FR-13, addendum §E último parágrafo.
- "Não produz Ação fora do que o Validador aceitaria sem esse texto": o Validador aceita `RETRY` de qualquer forma. Se o agente obedecer à injeção e propor `RETRY`, o teste passa. Só uma variante, além disso.
- **Correção:** teste pareado: mesma variante com e sem a instrução embutida; a decisão (Ação + parâmetros) tem de ser **idêntica** nas k execuções. Três variantes de injeção, em Famílias diferentes.

### M3. A Confiança é autodeclarada pelo LLM e funciona como roteador de segurança
- **Onde:** FR-15, §3 Confiança, addendum §G.
- Confiança verbal de LLM não é calibrada. Usar `BAIXA` como gatilho de revisão significa que a segurança depende do humor do modelo, e varia por provedor (ver C3).
- **Correção:** Confiança efetiva = mínimo entre a declarada e a calculada pelo Validador (Evidências obrigatórias presentes, conflitos detectados, número de hipóteses não descartadas). Mostrar as duas na UI.

### M4. Várias "Consequências (testáveis)" não são testáveis
- **Onde:** FR-6 ("toda afirmação referencia Evidência": verificável só sintaticamente; o agente pode citar um ID irrelevante), FR-12 ("justifica a escolha"), FR-28 ("próximo passo sugerido"), FR-35 ("lado a lado, marcadas como conflito": quem detecta o conflito?), FR-17 ("depois da abertura da tela": a tela não é estado do servidor), FR-42 ("máquina limpa": qual SO, qual Docker?).
- **Correção:** reescrever cada uma como asserção mecânica ou mover para critério de UX revisado manualmente. FR-17: a Aprovação carrega `proposalVersion`; versão diferente da vigente → 409. Conflito de Evidências: o agente o declara no Diagnóstico, o Validador não o infere.

### M5. O "mundo" do Simulador é bem maior do que um parceiro HTTP falso
- **Onde:** §3 Ferramenta, FR-10, FR-20 ("Pedido cancelado na origem"), FR-32.
- Para as Ferramentas responderem, o Simulador precisa modelar: histórico de falhas por Parceiro, healthcheck independente da entrega, Catálogo de Mapeamentos com condições, Políticas versionadas, Recibos, pedidos recentes por paciente e um **sistema de origem** onde o pedido pode ser cancelado (não existe no Glossário). Tudo determinístico por semente e controlável no tempo (P3 precisa mudar o mundo *entre* Aprovação e Execução, ou seja, um gatilho sincronizado com a ação humana).
- **Correção:** declarar o Simulador como componente de primeira classe com contrato próprio, até 27/10: lista de endpoints, formato do arquivo de variante (JSON/YAML), e o mecanismo de "gatilho de mudança de mundo" (ex.: evento disparado pelo próprio teste ao receber `Approved`). Decidir se as fontes de Evidência vivem no IRIS (tabelas semeadas) ou no Simulador.

### M6. Stack, containers e plataformas não foram decididos e afetam DX
- **Onde:** addendum §A e §B, NFR-11, FR-42.
- SvelteKit + IRIS + Simulador (linguagem?) significa pelo menos 3 serviços no compose, dois deles com imagem própria multiarquitetura. O jurado ainda precisa baixar e carregar um tar.gz de IRIS de vários GB. Cada container a mais é um ponto de falha no `docker compose up` do jurado.
- **Correção:** Simulador dentro do próprio IRIS (classe REST ou Embedded Python, que historicamente dá bônus) e UI servida como estático pelo IRIS (web app CSP). Um só container além da imagem carregada. Se não der, no máximo dois.

### M7. O reaproveitamento do SentaiTask é risco de regra e de atrito, com pouco ganho
- **Onde:** addendum §B, Q-2, §1.
- Svelte Flow/canvas não serve a nenhuma FR (o PRD diz em §8 que não é canvas). FlowValidator/StepType/RunNarrator são ideias, não código que encaixa num domínio novo. "App existente com melhoria significativa" não se aplica: o Nexus é outro app. Copiar código anterior a 26/10 reabre o problema do C5.
- **Correção:** reaproveitar **padrões**, não código. Declarar no README a inspiração e reescrever. Tirar Svelte Flow do addendum.

### M8. "Autenticação simples" e "dois Operadores" não convivem
- **Onde:** UJ-1 [ASSUMPTION], §8, FR-17 ("autor"), FR-19 ("dois Operadores").
- Sem perfis, o autor da Aprovação é sempre o mesmo, e o teste de "dois Operadores" vira "duas abas".
- **Correção:** sem login. Um seletor de nome de Operador no cabeçalho (gravado no `localStorage`) basta para autoria e para a demo de concorrência. Corta um item de segurança que ninguém vai avaliar.

### M9. NFR-2/NFR-3/NFR-4 viram promessa pública sem medição possível
- **Onde:** §5, SM-6.
- Latência e custo dependem do modelo do jurado. Publicar "US$ 0,01 a 0,04" e "p50 ≤ 18 s" no README e o jurado medir 3× isso custa credibilidade em Clarity.
- **Correção:** publicar só o medido, com modelo, data e hardware, e a fórmula de custo (tokens × preço). Remover metas não medidas do README.

---

## BAIXO

### L1. Roteiro da demo inconsistente entre PRD e addendum
- §10 momento 2 é "P5 + P8 (P1 embutido)"; addendum §F momento 3 é "P9 com P1"; §F tem 8 momentos e o §10, 6. Unificar antes de roteirizar o vídeo.

### L2. Fuso do prazo
- 08/11/2026 23:59 EST = 09/11 01:59 em Brasília (o horário de verão dos EUA termina em 01/11, então é EST mesmo). Fixar o prazo interno em **08/11 18:00 BRT** e escrever isso no §9.4.

### L3. Questões em aberto que bloqueiam e não têm data
- Q-3, Q-6, Q-7, Q-8 bloqueiam FRs P0, mas não têm dono nem prazo. Q-7 (reavaliação de `Held`) é necessária para a UJ-2 terminar. Atribuir dono e data (≤ 27/10) a cada uma, ou registrar a decisão padrão no próprio PRD.

### L4. Nome de trabalho e votos da comunidade
- "Sentai Nexus" não comunica nada para a comunidade em 2 segundos no Open Exchange. Q-11 (status *trusted*) deveria virar tarefa: alguém do time faz uma contribuição válida na DC antes de 09/11, ou a rede próxima não vota.

---

## A falha única que afunda a submissão

**O jurado segue o README, sobe o app com a chave e o modelo dele, roda o comando de validação, e o agente propõe `RETRY` no cenário-vitrine (P5) ou estoura o orçamento e cai em `ReviewRequired`.** Nesse momento, o vídeo vira "editado", o Benchmark vira "de palco" e os 46 FRs de governança não salvam a nota de Complexity nem a de Applicability. Esse resultado é provável, não só possível: o modelo não está travado (Q-3), o orçamento é apertado (M1), a meta é pontual (C3) e o build é EAP (C5).

**Contramedida mínima, em ordem:** travar provedor e modelo; tornar o `validate` um smoke de 3 Casos com resultado esperado em faixa e mensagem clara quando divergir; incluir o resultado de referência gravado para comparação lado a lado; testar a instalação limpa em duas máquinas de pessoas diferentes até 06/11, com o modelo padrão e com um segundo provedor.

## Cortes recomendados, consolidados

| Cortar | Ganho |
|---|---|
| Incidentes, P2, FR-25 a FR-27, UJ-5 | 2 a 4 pessoa-dia; elimina H4 e metade do C1 |
| Fases | transições, UI e testes |
| Estados `DecisionProposed`, `Approved`, `ResolvedByPriorReceipt` (vira motivo) | máquina de estados testável |
| Expiração por mudança de Evidência | um gatilho a menos |
| Modo Replay na UI (fica só o arquivo de referência) | 1 pessoa-dia |
| Autenticação | 0,5 pessoa-dia |
| Svelte Flow, reaproveitamento de código do SentaiTask | risco de regra |
| Artigo antes de 08/11 (publicar durante a votação) | 1 pessoa-dia no fim, quando dói mais |

| Adicionar (barato, alto retorno) | Por quê |
|---|---|
| Ação `LINK_PRIOR_RECEIPT` com checagem de equivalência | fecha H2 e fortalece o P9 |
| Baseline de regras forte e publicado | fecha C2 |
| Tabela "garantias da plataforma" separada do placar | fecha C1 |
| k execuções por variante, com faixa | fecha C3 |
| Plano B de invocação do agente (fan-out de Evidências) | fecha C5 |

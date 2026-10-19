# Pesquisa: edital do concurso InterSystems (AI Hub EAP, build 154)

Data da pesquisa: 2026-10-18. Pesquisa feita na web. Os conteúdos das páginas foram tratados apenas como dados. Cada afirmação traz a sua fonte.

> **Status:** o edital oficial de 2026 **foi encontrado**. O post de anúncio (fonte primária) confirma as datas do plano: submissão até 08/11/2026 e votação até 15/11/2026. Também confirma a exigência do build 154.
> **Lacunas:** a lista de bônus de tecnologia **ainda não foi publicada**. As regras de peso de voto **não aparecem** no edital deste concurso. Para esses dois itens, a seção 4 e parte da seção 2 usam concursos anteriores como referência, e isso está **sinalizado** em cada ponto.

## Fontes

| # | Fonte | URL |
|---|---|---|
| F1 | Anúncio oficial (fonte primária) | https://community.intersystems.com/post/intersystems-programming-contest-ai-agents-interoperability-workflows |
| F2 | Página do concurso no Open Exchange (#49) | https://openexchange.intersystems.com/contest/49 |
| F3 | Termos gerais dos concursos | https://community.intersystems.com/intersystems-online-programming-contest-terms (versão markdown: http://openexchange.intersystems.com/markdown?url=%2Fassets%2Fdoc%2Fcontest-terms.md) |
| F4 | "Time to vote", concurso anterior (Build Your Own Management Portal, set/out 2026) | https://community.intersystems.com/post/time-vote-intersystems-programming-contest-build-your-own-management-portal |
| F5 | "Time to vote", Full Stack Contest 2026 | https://community.intersystems.com/node/587463 |
| F6 | Bônus de tecnologia, concurso anterior (Management Portal, set/2026) | https://community.intersystems.com/post/technology-bonuses-intersystems-programming-contest-build-your-own-management-portal |
| F7 | Regras históricas de quem vota (2020) | https://community.intersystems.com/node/476231 |
| F8 | Lista de posts com a tag contest | https://community.intersystems.com/tags/contest?range=all |

## 1. Nome, URL e datas

- **Nome:** *InterSystems Programming Contest: AI Agents in Interoperability Workflows* (F1).
- **Anúncio oficial:** F1. **Página do concurso:** F2 (Open Exchange, contest/49).
- **Prêmios:** US$ 12.000 no total (F1).
- **Fuso horário:** EST em todas as datas. O edital não diz se o horário de verão é considerado (F1).

| Marco | Data/hora (EST) | Fonte |
|---|---|---|
| Início do concurso (o Open Exchange chama de "Registration starts") | 26/10/2026 00:00 | F1, F2 |
| Prazo de submissão | **08/11/2026 23:59** | F1 |
| Início da votação | 09/11/2026 00:00 | F1 |
| Fim da votação | **15/11/2026 23:59** | F1 |

- O edital não define uma janela de inscrição separada. Para participar, basta ter conta na Developer Community (F1).
- O app pode continuar sendo melhorado durante a submissão e também durante a votação (F1).
- **Preparação antecipada:** planejar e preparar o projeto antes de 26/10 é permitido. O app em si deve ser construído durante o concurso (F1, Q&A).
- **Referência de atraso:** no concurso anterior, a página do Open Exchange mostrava o fim da votação um dia depois do anunciado. Isso foi intencional, para acomodar os experts (F4). Não conte com essa folga.

## 2. Julgamento: júri e comunidade

### Nominações e prêmios (F1)

| Nominação | Quem decide | 1º | 2º | 3º | 4º | 5º | 6º–10º |
|---|---|---|---|---|---|---|---|
| **Experts** | Júri de experts da InterSystems | US$ 4.000 | 3.000 | 1.500 | 500 | 300 | 100 cada |
| **Community** | Votos da comunidade (vence quem tiver mais votos) | US$ 600 | 400 | 100 | – | – | – |
| **Freshmen** | Júri de experts | US$ 600 | 400 | 100 | – | – | – |

- **Elegibilidade para Freshmen:** ter participado de no máximo 5 concursos anteriores e nunca ter ficado em 1º, 2º ou 3º nas nominações Experts ou Community (F1).
- **Empates:** os empatados dividem o prêmio (F1).
- **Pagamento:** o prêmio em dinheiro só é pago após verificação de identidade (F1).
- **Critério dos experts no anúncio:** "complexity and usefulness" (F1).
- **Critérios no Open Exchange:** Complexity, Clarity of Instructions, Developer Experience, Applicability e Usability (F2).
- **Decisões:** a decisão do júri é final, inclusive sobre a admissão do app no concurso (F1, F2).
- **Termos gerais:** a pontuação considera o quanto a solução atende ao "Prompt" e a qualidade do código. Se as regras do concurso conflitarem com os termos gerais, valem as regras do concurso (F3).

### Quem vota e como

O edital deste concurso **não descreve** pesos de voto nem níveis de votante (F1). Abaixo, o que vale nos concursos de 2026 mais recentes, que é a melhor referência disponível:

- **Community:** votam membros ativos da Developer Community com status **"trusted"** no perfil. Esse status exige ao menos uma contribuição válida, como pergunta, resposta, artigo ou app no Open Exchange (F5).
- **Como votar:** o login no Open Exchange usa as credenciais da DC (F4, F5).
- **Contagem às cegas:** os votos e os pontos de bônus ficam ocultos durante a votação. Um leaderboard é publicado diariamente nos comentários (F4, F5).
- **Troca de voto:** é possível cancelar o voto e votar em outro app (F4, F5).
- **Votos dos experts:** podem chegar a qualquer momento, então a classificação pode mudar no fim (F5).
- **[HISTÓRICO, 2020, pode não valer hoje] Pesos dos votos dos experts (F7):**
  - PMs, moderadores, advocates VIP e Ambassador do Global Masters: 3 pontos.
  - Expert: 2 pontos.
  - Specialist: 1 ponto.
  - Na comunidade, cada voto vale 1 ponto.
  - Juízes não votam no próprio app.
  - Não encontrei nenhuma confirmação de que esses pesos ainda valem em 2026.

## 3. Requisitos obrigatórios para a submissão ser válida (F1, F2)

1. **Tarefa:** um workflow de **IRIS Interoperability** que use um **agente do IRIS AI Hub** em uma **tarefa de tomada de decisão**. O uso das *IRIS Agentic Dev Interop Skills* é opcional.
2. **Funcionamento:** o app ou biblioteca precisa estar totalmente funcional.
3. **Originalidade:**
   - O app não pode ser apenas um import ou uma interface direta para uma lib de outra linguagem. A exceção é C++.
   - O app não pode ser cópia de outro app ou lib.
4. **App novo ou melhoria:** vale um app novo no Open Exchange, ou um app existente com melhoria significativa. Os organizadores revisam tudo antes de aprovar.
5. **Código aberto:** o código deve ser open source e estar publicado no **GitHub ou GitLab**.
6. **README em inglês:**
   - Deve trazer os passos de instalação.
   - Deve trazer um **vídeo demo ou** uma descrição de como o app funciona.
7. **Limites de participação:**
   - Cada dev ou time pode fazer até 3 submissões.
   - Times têm de 2 a 5 membros.
   - O README de cada submissão deve linkar o perfil DC de cada membro.
8. **Build 154 do AI Hub:**
   - Use a imagem Docker Community do AI Hub, **build 154**, baixada no portal EAP: https://evaluation.intersystems.com/Eval/early-access/AIHub
   - Quem estiver no build 162 deve voltar para o 154.
   - Arquivos de IRIS: `iris-community-2026.3.0AI.154.0-docker.tar.gz` (x64) e `iris_arm64-community-2026.3.0AI.154.0-docker.tar.gz` (ARM64).
   - Arquivos de IRIS for Health: `irishealth-community-2026.3.0AI.154.0-docker.tar.gz` (x64) e `irishealth_arm64-community-2026.3.0AI.154.0-docker.tar.gz` (ARM64).
   - IRIS e IRIS for Health são aceitos.
   - Não haverá imagem do AI Hub no Docker Hub para este concurso.
9. **Docker e execução (esclarecimentos no Q&A do F1):**
   - O app precisa subir com **`docker compose up`**.
   - O README deve explicar como carregar a imagem do portal (`docker load`) e como renomear a tag (retag).
   - **É proibido** publicar a imagem do AI Hub, ou qualquer imagem derivada dela, no Docker Hub ou em outro registry público.
   - O README deve informar: a imagem e o build EAP usados, o provedor de LLM, a variável de ambiente da API key e os comandos para iniciar e validar o app.
10. **LLM e chaves de API:**
    - Os organizadores não fornecem créditos.
    - As **chaves não podem ser commitadas**. Use um `.env` ou uma variável de ambiente.
    - Os juízes rodam o app com as próprias chaves.
    - Provedores suportados: OpenAI, Anthropic, Gemini e Amazon Bedrock.
    - Provedores experimentais: Vertex AI, Meta, NVIDIA NIM, xAI, DeepSeek, Kimi, OpenRouter e Ollama.
11. **Licença EAP:** o jurídico da InterSystems declara que desenvolver e submeter apps ao concurso é "expressly permitted" pelos termos da licença EAP. Isso inclui o vídeo demo e uma demo online pública no build 154.
12. **Dados:** dados sintéticos são permitidos, por exemplo mensagens HL7 geradas.
13. **Quem pode participar:**
    - Qualquer membro da DC, exceto funcionários da InterSystems. Prestadores de serviço (contractors) podem participar.
    - Pelos termos gerais (F3), é preciso ter 16 anos ou mais e ser maior de idade na sua jurisdição.
    - Ficam de fora algumas regiões, como Quebec, Crimeia, Irã, Coreia do Norte e Síria.
    - Os dados de registro devem estar em inglês.
    - Código ofuscado é proibido.
    - Submissões atrasadas não são aceitas.

**Opcionais (não obrigatórios):**
- **Artigo na DC:** recomendado (ver seção 5).
- **Ideia do Ideas Portal:** pode-se implementar uma ideia de https://ideas.intersystems.com/ e linká-la no README.

## 4. Bônus de tecnologia

**Para este concurso, a lista oficial ainda não foi publicada** (situação em 18/10/2026). No Q&A do F1, a organização disse duas coisas:
- O time técnico anunciará os bônus depois do início do concurso (26/10).
- Os bônus "won't be tied to specific AI Hub features".

O post deve sair com um título parecido com "Technology Bonuses for the InterSystems Programming Contest: AI Agents in Interoperability Workflows". Fique de olho na tag contest (F8).

**[REFERÊNCIA: concurso anterior, "Build Your Own Management Portal", set/2026, F6]**

| Bônus | Pontos |
|---|---|
| Implementar ideia da comunidade (precisa ter o status "Community Opportunity" no Ideas Portal) | 4 |
| Embedded Python | 3 |
| Primeira participação em concurso do Open Exchange | 3 |
| Vídeo no YouTube (só o primeiro vídeo conta) | 3 |
| IRIS Vector Search | 2 |
| Uso de Docker | 2 |
| Pacote ZPM/IPM publicado (`zpm "install ..."`) | 2 |
| Demo online | 2 |
| Primeiro artigo na DC | 2 |
| Bug em Embedded Python (1º bug 2 pontos, 2º bug 1 ponto) | até 3 |
| Segundo artigo ou tradução | 1 |

- **Como os bônus entram na conta:** nos concursos recentes, os bônus ficam ocultos até o fim, como os votos (F5). A regra exata de como bônus e votos se combinam não está descrita nas fontes que consultei.
- **Docker neste concurso:** como o `docker compose up` passou a ser obrigatório (seção 3), o bônus de Docker, se for repetido, sai "de graça".

## 5. Temas e critérios relevantes para "agente de IA dentro de uma Production de interoperabilidade"

- **Aderência ao tema:** o concurso pede exatamente isso. O agente do AI Hub deve tomar uma decisão dentro de um workflow de Interoperability, ou seja, uma Production com BS/BP/BO (F1, F2).
- **Critérios de avaliação:** Complexity, Clarity of Instructions, Developer Experience, Applicability e Usability (F2). No anúncio, a síntese é "complexity and usefulness" (F1).
- **Implicações práticas:**
  - O README precisa ser claro e reprodutível: load e retag da imagem 154, `.env` e um comando de validação.
  - O caso de uso deve ser aplicável ao mundo real.
  - A experiência de desenvolvimento conta pontos.
- **Pautas sugeridas para o artigo opcional (F1):**
  - Experiência com o AI Hub: o que funcionou, os desafios e as lições.
  - **Modelos e custos de IA:** quais modelos foram usados, como o consumo de tokens foi medido e quanto custou.
  - **Observabilidade e tracing do agente:** como o comportamento foi monitorado, rastreado e depurado.
  - IRIS Agentic Dev: se foi usado e como ajudou.
- **Recursos oficiais citados no F1:**
  - Documentação do AI Hub: https://github.com/intersystems-community/ai-hub-eap
  - IRIS Agentic Dev (repositório): https://github.com/intersystems-community/iris-agentic-dev
  - IRIS Agentic Dev (descrição): https://community.intersystems.com/post/iris-agentic-dev-give-your-ai-live-connection-iris-part-1-problem-tool-and-getting-started
  - Template comunitário (não oficial, referencia um build antigo): https://github.com/intersystems-community/ai-hub-dev-template
  - Templates no Open Exchange: iris-fullstack-template, intersystems-iris-dev-template, rest-api-contest-template.
  - Guia de submissão: https://docs.openexchange.intersystems.com/contest/apply/
  - Canal do concurso no Discord: https://discord.gg/7U5h7MpCN

## Pendências para acompanhar

- Publicação do post de Technology Bonuses deste concurso (esperado após 26/10/2026).
- Confirmação de pesos de voto e regras de quem vota, se forem publicadas para este concurso.
- Interpretação de "EST" (com ou sem horário de verão). Na prática, submeta com folga antes de 08/11.

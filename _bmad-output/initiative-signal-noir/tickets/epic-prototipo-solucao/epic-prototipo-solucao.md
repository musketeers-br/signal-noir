---
id: 1
type: epic
title: "Protótipo navegável da solução (HTML, CSS, JS)"
parent: ../../initiative-signal-noir.md
covers: [R36, R37, R38, R39]
sources: [../../initiative-signal-noir.md]
companions: [../../../../contracts/openapi-signalnoir.yaml, ../../prd-signal-noir/prd-signal-noir.md]
after: []
refined: true
hitl: true
risk: low
owner: Henrique
reviewers: [Henry, José]
window: 21–24/10/2026
---

# Protótipo navegável da solução (HTML, CSS, JS)

## Description

Um protótipo descartável, em HTML, CSS e JavaScript puros, que mostra ao time e aos revisores como o Signal Noir final vai parecer e se comportar. Ele roda inteiramente no navegador, com dados sintéticos de fixture e um "roteiro" que simula as transições do Caso. Não tem backend, build nem dependências externas.

O protótipo existe para responder perguntas antes de B03 congelar o contrato de UX e a API:
- o detalhe em camadas torna a Proposta verificável?
- a tela de Aprovação deixa claro o efeito exato?
- espera, revisão e incerteza são distinguíveis?
- o Dossiê é útil quando o LLM falha?

Pela regra de construção durante o concurso, ele é material de preparação e não vira código da submissão (R38).

## Outcome

Henry e José navegam pelas jornadas principais em poucos minutos e respondem com base em telas reais, não em descrições: "é isto que vamos entregar". Os ajustes viram decisões registradas antes de 25/10.

## Requirements

### Forma e restrições técnicas
- R1 (parent R36) A entrega são arquivos estáticos em `_bmad-output/initiative-signal-noir/prototype-signal-noir/`: `index.html`, `styles.css`, `fixtures.js`, `engine.js` (API simulada sem DOM), `app.js`, `tests/engine.test.js`, `README.md` e `findings.md`.
- R2 (parent R36) O protótipo abre com duplo clique (`file://`), sem servidor. Usa scripts clássicos, sem módulos ES nem `fetch` de JSON local, porque os dois falham em `file://`. Não usa framework, CDN nem build.
- R3 (parent R36) O roteamento é por hash (`#/cases`, `#/cases/<caseId>`, `#/benchmark`), espelhando o AD-17.
- R4 (parent R36) A lista e a Linha do Tempo se atualizam por um "polling" simulado a cada 1–2 s, que consome eventos do roteiro, sem recarregar a página.

### Fidelidade ao contrato
- R5 (parent R37) As fixtures usam os nomes de campos, os estados (`CaseState`), as Ações, a Confiança, os prefixos de ID (`case_`, `prop_`, `appr_`, `exec_`, `evid_`, `cmd_`) e os códigos de erro (`STALE_VERSION`, `INVALID_TRANSITION`, `VALIDATION_FAILED`…) de `contracts/openapi-signalnoir.yaml`.
- R6 (parent R37) Quando a tela pede um dado que o contrato não tem, ou o contrato tem um dado que nenhuma tela usa, o caso é anotado em `findings.md` como proposta de mudança de contrato para B03.

### Telas
- R7 (parent R36) **Lista de Casos** com estado, Parceiro, idade, pendência de Aprovação e o rótulo `SYNTHETIC`. Um Caso novo ou uma mudança de estado aparece sem recarga.
- R8 (parent R36) **Detalhe do Caso em camadas:**
  1. cabeçalho com estado, `caseVersion`, `orderId` e link simulado para o Visual Trace;
  2. Evidências como fatos, com fonte e momento, e as conflitantes lado a lado;
  3. Diagnóstico, em que cada afirmação navega até a Evidência que a sustenta;
  4. Proposta com Ação, parâmetros, Escopo, Confiança, pré-condições, hipóteses descartadas, veredito do Validador e métricas (modelo, duração, Chamadas, tokens, custo), rotuladas como ilustrativas;
  5. Aprovação;
  6. Execução e Recibo;
  7. Linha do Tempo.
- R9 (parent R36) **Aprovação:**
  - mostra o efeito exato: payload antes e depois do Mapeamento, destino, versão da Proposta e prazo de validade com contagem regressiva;
  - pede o nome do Operador, rotulado como identificação declarada;
  - aprovar e negar são ações distintas e confirmadas.
- R10 (parent R36) **Dossiê de Revisão (P13):**
  - mostra o motivo, as Evidências consultadas, os dados divergentes, a ausência de informação separada de conclusão negativa e o próximo passo;
  - a escolha humana de uma Ação passa por um "Validador" simulado, que pode aceitar ou recusar.
- R11 (parent R36) **Relatório do Benchmark:**
  - tem duas partes, Decisão do Agente e Garantias da Plataforma, com denominadores;
  - um resultado de empate fica visível;
  - a página toda é rotulada como "dados fictícios de layout".

### Roteiro (painel de cenários exclusivo do protótipo)
- R12 (parent R36) **P5/P8b, caminho feliz:** HTTP 500 com erro semântico e dois Mapeamentos Aprovados; o Agente escolhe o aplicável; aprova; revalida; executa; `Resolved`.
- R13 (parent R36) **Aprovação dupla:** dois cliques ou duas abas resultam em uma única autorização efetiva; a segunda tentativa mostra o resultado sem novo efeito.
- R14 (parent R36) **Versão vencida:** a Proposta muda enquanto a tela está aberta; a Aprovação recebe `409 STALE_VERSION` e a interface pede para atualizar, nunca mostra sucesso.
- R15 (parent R36) **P3, revalidação impeditiva:** o Parceiro volta a falhar e o Caso vai para `Held`, ou o Pedido é cancelado e o Caso vai para `Cancelled`, com o motivo na Linha do Tempo e nenhum envio.
- R16 (parent R36) **Resposta perdida:**
  1. timeout após aceitação;
  2. estado de incerteza, com novo envio bloqueado inclusive para uma nova Proposta;
  3. Reconciliação encontra o Recibo;
  4. `Resolved`.
- R17 (parent R36) **Provedor indisponível:** o Caso vai para `ReviewRequired` com Dossiê que declara o motivo e as Evidências coletadas até ali.
- R18 (parent R36) **P9 (opcional, rotulado "condicionado"):** um Recibo candidato com identidade inequívoca leva a `ResolvedByPriorReceipt`; sem ela, leva a revisão.
- R19 (parent R36) O roteiro pode ser reiniciado a qualquer momento e é determinístico: a mesma sequência de cliques produz as mesmas telas.

### Qualidade mínima
- R20 (parent R36) O texto da interface está em inglês, com o vocabulário do domínio. O `README.md` e o `findings.md` do protótipo ficam em português.
- R21 (parent R36) O layout funciona de 360 px a desktop, toda ação é acessível por teclado com foco visível, e os estados não dependem só de cor.
- R22 (parent R36) Dados sintéticos estão rotulados em todas as telas. Nenhum dado real ou chave aparece.

### Aprendizado
- R23 (parent R39) `findings.md` registra o que funcionou, o que surpreendeu, as reações de Henry e José, as mudanças de contrato propostas e as decisões para B03 e B07/B10.
- R24 (parent R38, R39) Ao fim da revisão, o time decide e registra no memlog da iniciativa: descartar o protótipo, ou mantê-lo como referência visual fora da submissão. Ele nunca vira base do código de `ui/`.

## Constraints

- O protótipo não reaproveita código do SentaiTask (PRD Q-2) e não é copiado para `ui/`, para a imagem nem para o compose (R38).
- Se o esclarecimento de Q-1 vetar material de preparação no repositório, o protótipo sai do repositório antes de 26/10.
- Time-box: até 1,5 pessoa-dia de construção mais uma sessão de revisão de 45 min. Passando disso, cortar R11 e R18, nesta ordem.
- Não há integração com IRIS, AI Hub ou Simulador. Qualquer número exibido é ilustrativo.

## Done when

- O protótipo abre por `file://` num navegador atual, sem erros no console.
- Os roteiros R12 a R17 rodam do início ao fim, e cada um mostra o estado final esperado.
- Henry e José revisaram o protótipo numa sessão até 24/10.
- `findings.md` está preenchido e as propostas de mudança de contrato foram levadas a B03.
- A decisão de descartar ou manter está registrada no memlog da iniciativa.

## Boundaries

- Non-goal: backend, persistência real, chamadas de rede, autenticação.
- Non-goal: estética final. O DESIGN.md sai de uma rodada de `bmad-ux` depois do protótipo.
- Non-goal: cobertura de todos os estados e transições. B01 é a fonte normativa.

## References

- contract — ../../../../contracts/openapi-signalnoir.yaml
- prd — ../../prd-signal-noir/prd-signal-noir.md (§2.3 UJ-1 a UJ-4, §11.1 roteiro da demo)
- architecture — ../../architecture-signal-noir/architecture-signal-noir.md (AD-16, AD-17, Consistency Conventions)

## Notes

- Decision (20/10, Henrique): Henrique é o responsável. Henry revisa o domínio e José revisa os contratos.
- Decision (20/10, Henrique): texto da interface em inglês.
- Status (20/10): construído. `tests/engine.test.js` passa, e 19 verificações de interface passaram em Chrome headless, sem erros de console. Aguarda a revisão de Henry e José. Propostas de contrato F-1 a F-9 em `prototype-signal-noir/findings.md`.
- Open question: o protótipo também deve servir de rascunho do roteiro do vídeo (PRD §11.1)? Se sim, R12 a R16 seguem a ordem dos momentos 2 a 6.

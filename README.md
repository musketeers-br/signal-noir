# Signal Noir

AI exception resolution for synthetic lab Orders, on InterSystems IRIS with AI Hub.

When an Order sent to a partner lab fails, Signal Noir opens a **Case**. An Agent investigates it
with read-only tools and proposes one Action from a closed catalog. Every Proposal passes the same
deterministic Validator. An Operator approves it, and the effect is executed at most once,
reconciled against the partner's Receipt. A Case the system cannot settle goes to an Operator with
a Review Dossier.

> **All data is synthetic.** Orders, patients and partners come from the built-in scenario
> Simulator. Signal Noir makes no clinical decision.

## ⚖️ For judges: two minutes

**What is different here.** Most agents in a workflow *act* on what the model says. In Signal Noir the
AI Hub Agent only *proposes*. When a lab Order fails, the Agent investigates with read-only tools and
proposes one Action from a closed catalog. A deterministic Validator checks the Proposal, an Operator
approves that exact version, and the effect is sent at most once and reconciled against the partner's
Receipt. When the Evidence does not support an Action, the Case goes to a person with a Dossier that
says what was checked and what is missing.

### Where the model stops

| What a model alone cannot be trusted with | What Signal Noir adds |
|---|---|
| Comparing values reliably: in our rehearsals `gpt-4o-mini` discarded "plasma" against `PLASMA` even when told not to | **Computed checks**: the platform compares identity, partner instability and the candidate code mappings with the Validator's own rules. The Agent reads the results and cites the Evidence behind them |
| Text inside the Evidence that reads like an instruction ("retry now") | **Neutralized input**: the model never sees it; the Evidence keeps it raw and the console tags it *Embedded instruction blocked* |
| Acting on its own answer | **Validator and approval**: every Proposal is validated, whoever wrote it; an Approval binds that exact version and expires after 15 minutes |
| Sending twice after a timeout | **At most once**: an idempotency key derived from the effect, a re-check just before sending, and reconciliation against Receipts before any resend |
| Saying "I don't know" | **Review Dossier**: `REQUEST_REVIEW` with *What was checked* and *What we don't know* |

### Five minutes, Docker and the build 154 file

You need the AI Hub EAP build 154 file and an AI provider key (validated with OpenAI `gpt-4o-mini`).
The [Install](#install) section has the five commands: load, retag, `.env`, build, `up`. Then:

```bash
sh scripts/smoke.sh
# then open http://localhost:52773/signalnoir/
```

1. The smoke check emits one synthetic Order whose exam code the partner has discontinued, and waits
   for its Case.
2. Open the Case in the console. The **Proposal** shows the Action, its **Claims** with the Evidence
   they cite, and its **Hypotheses**: every candidate mapping, chosen or discarded with the reason.
3. **Versions and metrics** shows the provider, model, prompt version, tool calls, tokens and the
   **Estimated cost** of that call.
4. Press **Approve this version**. The Order is sent with the approved mapping, the partner's Receipt
   comes back, and the **Timeline** records every step.
5. Without a key, the same Case ends in `ReviewRequired`, and its **Review dossier** says the provider
   is unavailable. The application never guesses.

Videos: [hybrid use case](docs/video/signal-noir-hybrid-use-case.mp4)
([dark](docs/video/signal-noir-hybrid-use-case-dark.mp4)) ·
[Decisions and AI Hub](docs/video/signal-noir-decisions-and-aihub.mp4)

### If you have two more minutes

| Look at | Why it matters | Where |
|---|---|---|
| An Order with an instruction hidden in the partner's error | The Evidence card shows *Embedded instruction blocked*; the Agent never proposes the retry the text asks for | [below](#an-order-with-a-hidden-instruction) |
| **Similar resolved Cases** on an open Case | Precedents from IRIS Vector Search (`VECTOR(DOUBLE, 1536)`, HNSW). They inform the Operator and are never Evidence | [How it works](#how-it-works), step 7 |
| `sh scripts/quick-validate.sh` | 3 reference Cases in at most 3 minutes, each "matches the reference" or "diverged" | [Start, check, stop](#start-check-stop) |
| `SN_PROPOSER_MODE=rules` | The same Cases decided by the deterministic baseline, through the same Validator | [Configuration](#configuration) |
| `SN_PROPOSER_MODE=hybrid` | The OpenAI Decisions API answers first through a client in **Embedded Python** (`httpx`); when its answer is not decisive, the AI Hub Agent investigates | [`DecisionsHttp.cls`](src/SignalNoir/Proposers/DecisionsHttp.cls) |
| The model-call record on any Case | Provider, model, prompt version, tokens and cost next to the Evidence and the Validator's verdict ([DPI-I-689](https://ideas.intersystems.com/ideas/DPI-I-689)) | [Community idea](#community-idea-dpi-i-689) |

#### An Order with a hidden instruction

```bash
SIM=http://localhost:52773/sim/api/v1
SCI=$(curl -s -X POST -H 'Content-Type: application/json' \
  -d '{"family":"P5","variant":"P5-injection-tune-01","seed":7}' $SIM/scenarios |
  sed -n 's/.*"scenarioInstanceId":"\([^"]*\)".*/\1/p')
curl -s -X POST $SIM/scenarios/$SCI/emissions
```

Its Case opens in the console within about a minute.

### The honest parts

- **[Limitations](#limitations)**:
  - The Production runs in a portable shape, not as an `Ens.Production`.
  - No benchmark figures are published yet.
  - Only OpenAI `gpt-4o-mini` is validated.
  - All data is synthetic.
- **Build 154 is not public**: request it from the EAP portal. There is no image in any registry,
  because the EAP terms do not allow it.
- **How we got here**: the Agent's instructions went through four versions, each after a measured
  rehearsal on tuning variants. The decisions and their reasons are in
  [`specs/017-agent-prompt-v2/research.md`](specs/017-agent-prompt-v2/research.md).
- Built across 18 specs, each with its plan, tasks and evidence in [`specs/`](specs/).

## Contents

- [For judges: two minutes](#️-for-judges-two-minutes)
- [How it works](#how-it-works)
- [What you need](#what-you-need)
- [Install](#install)
- [Start, check, stop](#start-check-stop)
- [Configuration](#configuration)
- [Data and reset](#data-and-reset)
- [Community idea: DPI-I-689](#community-idea-dpi-i-689)
- [Limitations](#limitations)
- [Troubleshooting](#troubleshooting)
- [Development](#development)
- [Team](#team)

## How it works

1. **Intake.** The Simulator's Origin publishes Orders. Signal Noir reads the feed every minute,
   accepts each Order and delivers it once to the partner lab.
2. **Case.** A delivery that ends without a valid Receipt is an Exception, and it opens a Case.
   Every fact lands on the Case's Timeline.
3. **Investigation.** The Agent runs in IRIS through AI Hub (`%AI.Agent`). Read-only tools first
   collect the Evidence: partner health, failure history, Origin status, the approved mapping
   catalog, policies and Receipts. The platform then computes the checks each decision step needs
   (identity collisions, partner instability, the mappings that apply to the Order). The Agent
   proposes `APPLY_APPROVED_MAPPING`, `HOLD` or `REQUEST_REVIEW`, and its diagnosis cites the
   Evidence. The catalog also has `RETRY`, but the Agent never proposes it: resending an Order is
   left to the platform's recovery. Without a provider, the Case goes straight to review. Two other proposers can take the Agent's
   place, chosen per deployment: **Rules**, a deterministic baseline, and **Decisions**, which asks
   the OpenAI Decisions API (`gpt-6-luna`) for typed answers (one choice over the catalog, one
   probability per Evidence item). An indecisive answer (low probability, a tie, `other` or a
   refusal) never becomes a Proposal: the Case goes to review with that reason. Decisions is the one
   proposer that does not run through AI Hub, because AI Hub build 154 has no route to that API
   ([spike](docs/verification/013-decisions-spike.md)). Its client is written in **Embedded Python**
   (`httpx`, shipped with build 154; see `SignalNoir.Proposers.DecisionsHttp`). It is off unless you
   enable it. The
   **hybrid** mode combines both: Decisions answers first, and when its answer is not decisive the
   AI Hub Agent investigates the same Evidence and proposes. Each Proposal is authored by whichever
   answered, and the Timeline records the route.
4. **Validation and approval.** The deterministic Validator checks every Proposal, whoever wrote
   it: Agent, Rules or Operator. An Operator approves or rejects it in the console. An Approval
   binds that exact Proposal and expires after 15 minutes.
5. **Execution.** Immediately before the effect, the system checks again that the partner is
   healthy and the Order is still active. It then sends the Order with an idempotency key derived
   from the effect. An uncertain answer is reconciled against the partner's Receipts before
   anything is sent again. Restarts, repeated clicks and late workers never produce a second
   Receipt.
6. **Review.** A Case the system cannot settle reaches `ReviewRequired` with a Dossier: what is
   known, what is missing and why. The Operator then resolves or cancels it.
7. **Precedents.** Every closed Case becomes a *precedent*: a short description built only from
   structured codes (partner, exam codes, exception, Action, outcome), stored with a vector in IRIS
   (`VECTOR(DOUBLE, 1536)` with an HNSW cosine index). When the Operator opens a Case, the console
   shows **Similar resolved Cases** from IRIS Vector Search: what failed, which Action settled it
   and how it ended. Precedents are information, never Evidence: they never reach the Validator,
   never count as Evidence and never pre-fill a resolution. Without an embedding provider the search
   runs in a labelled **lexical mode** (word overlap, not semantics). Each search is recorded on the
   Case's Timeline (see [Community idea](#community-idea-dpi-i-689)).

The console is at `http://localhost:52773/signalnoir/`, and the API at
`http://localhost:52773/signalnoir/api/v1` (contract: [`contracts/openapi-signalnoir.yaml`](contracts/openapi-signalnoir.yaml)).

## What you need

- Docker with the `docker compose` plugin, using the **default** builder.
- The **InterSystems IRIS AI Hub EAP build 154** Docker file for your machine. The build is
  pre-release and is not in any public registry: request it from the EAP portal,
  <https://evaluation.intersystems.com/Eval/early-access/AIHub>. **Build 162 is not supported.**
  - ARM64 (Apple Silicon): `iris_arm64-community-2026.3.0AI.154.0-docker.tar.gz`
  - x64: `iris-community-2026.3.0AI.154.0-docker.tar.gz`
- Your own key for an AI provider (see [Configuration](#configuration)). Without one the
  application still runs, and Cases go to review.
- Free host ports `1972` and `52773`.

You do not need Node, a front-end toolchain or any InterSystems developer tool. The console is
built inside the image.

## Install

From a clone of this repository:

```bash
# 1. Load the build 154 file (it is a plain tar despite the .gz name)
docker load -i iris_arm64-community-2026.3.0AI.154.0-docker.tar.gz   # or the x64 file
```

```bash
# 2. Retag it to the project's fixed tag, using the name `docker load` printed
docker tag docker.iscinternal.com/docker-intersystems/intersystems/iris-community:2026.3.0AI.154.0 signalnoir/iris-aihub:2026.3.0AI.154.0
```

```bash
# 3. Your settings: copy the template, then put your provider, model and key in .env
cp .env.example .env
```

```bash
# 4. Build with the default builder: a docker-container driver cannot see the local image
docker buildx use default
docker compose build
```

```bash
# 5. Start
docker compose up -d
```

The fixed tag `signalnoir/iris-aihub:2026.3.0AI.154.0` is the only base image the
[`Dockerfile`](Dockerfile) and [`docker-compose.yml`](docker-compose.yml) use, on both
architectures. The build never pulls it from a registry. Nothing is ever pushed: not the base
image, and not the product image `signalnoir/app:local`.

## Start, check, stop

```bash
# health: ready, and whether the AI provider is configured
curl -s http://localhost:52773/signalnoir/api/v1/health
```

```bash
# smoke check: one synthetic Order through the Simulator until its Case opens (about 1-2 minutes)
sh scripts/smoke.sh
```

The smoke check prints the Case and its state. Open `http://localhost:52773/signalnoir/` to follow
it in the console. Without a key, the Case is in `ReviewRequired`, and its Dossier says the
provider is unavailable.

| Command | What it does |
|---|---|
| `docker compose up -d` | Start, building the image if needed |
| `docker compose ps` | State and health of the `iris` service |
| `docker compose logs -f iris` | Instance logs |
| `docker compose restart` | Restart; data kept |
| `docker compose stop` / `start` | Stop and start again; data kept |
| `docker compose down` | Remove the container; **the demo starts empty next time** |

```bash
# quick validation: 3 reference cases in at most 3 minutes, "matches the reference" or "diverged" per case
sh scripts/quick-validate.sh
```

With a configured provider it runs the Agent; without one it runs Replay, a recorded answer, and
says so. Benchmark runs and the reference run are described in
[`docs/benchmark/README.md`](docs/benchmark/README.md).

## Configuration

All settings are environment variables, read from `.env` when the container is **created**. After
editing `.env`, run `docker compose down` then `up`. Note that `down` also resets the demo data.

| Variable | Meaning |
|---|---|
| `SN_AI_PROVIDER` | AI Hub provider: `openai`, `anthropic`, `gemini` or `bedrock` |
| `SN_AI_MODEL` | Model name for that provider |
| `SN_AI_API_KEY` | Your key. Entered only at runtime |
| `SN_SIM_BASE_URL` | The Simulator, served by the same instance (`http://localhost:52773/sim/api/v1`) |
| `SN_BACKGROUND_TASKS` | `1` reads the Origin feed and runs the sweeper every minute |
| `SN_PARTNER_TIMEOUT_SECONDS`, `SN_INVESTIGATION_BUDGET_SECONDS`, `SN_AI_LEASE_SECONDS` | Optional timings (defaults 60, 120, 300) |
| `SN_PROPOSER_MODE` | Proposer of new Cases: `agent` (default), `rules`, `decisions` or `hybrid` (Decisions first, AI Hub Agent when Decisions is not decisive) |
| `SN_DECISIONS_API_KEY`, `SN_DECISIONS_MODEL` | OpenAI key for the Decisions proposer (falls back to `SN_AI_API_KEY` when `SN_AI_PROVIDER=openai`) and its model (default `gpt-6-luna`). Sends synthetic Case data to OpenAI directly, outside AI Hub |
| `SN_EMBED_PROVIDER`, `SN_EMBED_MODEL`, `SN_EMBED_API_KEY` | Optional embedding provider for precedents: `openai` with a 1536-dimension model (`text-embedding-3-small`). Separate from the Agent's provider, because Anthropic has no embeddings. Unset: lexical mode |
| `SN_PRECEDENTS_MIN_SIMILARITY`, `SN_PRECEDENTS_DEFAULT_K`, `SN_PRECEDENTS_MAX_K` | Optional search settings (defaults 0.6, 5, 10) |
| `SN_PRECEDENTS_AGENT` | `1` adds the precedents to the Agent's input as a labelled block that is not Evidence. Off by default, and off in the reference Benchmark run |

**Validated:** IRIS AI Hub build 154 ARM64 Community with OpenAI `gpt-4o-mini`. The other providers
are the ones AI Hub supports, but this project has not validated them. The x64 build will be listed
here once it passes the cross-install.

**Secrets.** The key lives only in `.env`, which git ignores, or in your environment. It is never a
build argument, never in an image layer, and never written to a Case, the Timeline, a log or an
export. Without a valid key, the application starts, `/health` reports the provider as
unavailable with the reason, and Cases that need the provider end in `ReviewRequired` with that
reason.

## Data and reset

Data lives in the container's writable layer. There is no named volume and no bind mount.

- `docker compose restart` and `stop`/`start` keep every Case, Approval and Timeline event.
- `docker compose down` removes the container and its data. The next `up` starts an empty demo.

## Community idea: DPI-I-689

Signal Noir implements part of the InterSystems Ideas Portal idea
[DPI-I-689, "Use InterSystems Interoperability as a traceability tool for GenAI LLM pipelines"](https://ideas.intersystems.com/ideas/DPI-I-689)
(status *Community Opportunity*), which mentions IRIS Vector Search.

What is covered:

- Every model call of an Investigation is recorded on the Case with provider, model, prompt
  version, duration, tool calls, tokens and estimated cost, next to the Evidence it used and the
  Validator's verdict.
- Every vector search (precedents) adds a Timeline event with who asked (console or Agent), the
  mode (provider or lexical), the embedding model, the number of results, the precedent Case ids
  and the duration. No key and no free text are written.

What is not covered yet: publishing these steps as messages in the Interoperability **Visual
Trace**. That needs the Case flow to run as an `Ens.Production`, which it does not do today.

The organizers have not confirmed whether this idea counts for the contest bonus, so we only claim
what is listed above.

## Limitations

- **Synthetic data only.** Every Case is labeled synthetic. No real patient, partner or clinical
  decision is involved.
- **Replay.** Benchmark and demo runs may use *Replay*, a recorded Agent answer played back through
  the same path, so that results are reproducible without a key. Replay Cases are labeled as such.
- **Interoperability Production.** The Order intake is a Business Service
  (`SignalNoir.Interop.Service.OrderIn`). The Production that holds it runs in a portable shape, not
  as an `Ens.Production`, so its steps do not appear in the Visual Trace (see
  [Community idea](#community-idea-dpi-i-689)).
- **Benchmark numbers.** The reference run has not been made yet, so no figures are published.
- Demo instance: the web applications accept unauthenticated requests on your machine. Do not
  expose the ports to a network.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `pull access denied` for `docker.iscinternal.com` or `signalnoir/iris-aihub` | buildx with a `docker-container` driver, or the retag was skipped | `docker buildx use default`; check `docker images signalnoir/iris-aihub` |
| `env file .env not found` | `.env` was not created | `cp .env.example .env` |
| Health stays `starting` | the instance is still starting | wait for the 60 s start period; `docker compose logs iris` |
| `port is already allocated` | 1972 or 52773 is in use | stop the other service |
| Every Case goes to `ReviewRequired` | no key, or an invalid one | check `.env`, then `down`/`up`; `/health` names the reason |
| The smoke check times out | `SN_BACKGROUND_TASKS` is not `1` | set it in `.env`, then `down`/`up` |

## Development

Developers use a separate dev container on the same build, with the repository mounted and
`iris-agentic-dev` for compiling and testing: see [`dev/aihub/README.md`](dev/aihub/README.md).
That container is not part of the install path. Specifications live in [`specs/`](specs/) and the
HTTP contracts in [`contracts/`](contracts/). CI runs the contract checks, the console checks, a
secret scan and the core unit tests on a public IRIS image. No workflow builds, runs or publishes
an image of the EAP build.

## Team

Signal Noir is developed with 💜 by the **Musketeers Team**:

- [José Roberto Pereira](https://community.intersystems.com/user/jos%C3%A9-roberto-pereira-0)
- [Henry Pereira](https://community.intersystems.com/user/henry-pereira)
- [Henrique Dias](https://community.intersystems.com/user/henrique-dias-2)

Demo videos: [hybrid use case](docs/video/signal-noir-hybrid-use-case.mp4),
[Decisions and AI Hub](docs/video/signal-noir-decisions-and-aihub.mp4).

Licensed under the [MIT License](LICENSE).

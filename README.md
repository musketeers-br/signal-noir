# Signal Noir

AI exception resolution for synthetic lab Orders, on InterSystems IRIS with AI Hub.

When an Order sent to a partner lab fails, Signal Noir opens a **Case**. An Agent investigates it
with read-only tools and proposes one Action from a closed catalog. Every Proposal passes the same
deterministic Validator. An Operator approves it, and the effect is executed at most once,
reconciled against the partner's Receipt. A Case the system cannot settle goes to an Operator with
a Review Dossier.

> **All data is synthetic.** Orders, patients and partners come from the built-in scenario
> Simulator. Signal Noir makes no clinical decision.

## Contents

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
3. **Investigation.** The Agent runs inside the IRIS Production through AI Hub (`%AI.Agent`). It
   reads partner health, Order history, Origin status and Receipts, and proposes one of `RETRY`,
   `APPLY_APPROVED_MAPPING`, `HOLD` or `REQUEST_REVIEW`. The diagnosis cites the Evidence it used.
   Without a provider, the Case goes straight to review. Two other proposers can take the Agent's
   place, chosen per deployment: **Rules**, a deterministic baseline, and **Decisions**, which asks
   the OpenAI Decisions API (`gpt-6-luna`) for typed answers (one choice over the catalog, one
   probability per Evidence item). An indecisive answer (low probability, a tie, `other` or a
   refusal) never becomes a Proposal: the Case goes to review with that reason. Decisions is the one
   proposer that does not run through AI Hub, because AI Hub build 154 has no route to that API
   ([spike](docs/verification/013-decisions-spike.md)); it is off unless you enable it. The
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

The quick validation (3 reference cases in at most 3 minutes, match or diverged per case) and the
benchmark commands come with the benchmark feature. They are *pending* and will be listed here
when they ship.

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
- Approved mappings and versioned policies are reference data that is still being integrated.
  Until it lands, the Agent does not propose a mapping, and an approved mapping is held rather than
  sent.
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

Musketeers: José Roberto (IRIS and API), Henrique (validation and benchmark), Henry (Agent,
execution and console). Developer Community profiles: *pending*.

Demo video (at most 5 minutes): *pending*.

Licensed under the [MIT License](LICENSE).

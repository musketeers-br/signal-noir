# Dev environment on IRIS AI Hub build 154

Local, dev-only IRIS with AI Hub (EAP build 154, Community, ARM64) to compile, run the
`%UnitTest` suites and call the real Agent. The official image, compose and README are feature
012's; the root `Dockerfile` and `docker-compose.yml` are integration files and stay untouched.

## Once

1. From the EAP portal, download `iris_arm64-community-2026.3.0AI.154.0-docker.tar.gz`
   (x64 machines: `iris-community-2026.3.0AI.154.0-docker.tar.gz`). Keep it in the repo root:
   `*-docker.tar.gz` is git-ignored. The file is a plain tar despite its name.
2. Load and tag it (use the name `docker load` prints):

   ```sh
   docker load -i iris_arm64-community-2026.3.0AI.154.0-docker.tar.gz
   docker tag docker.iscinternal.com/docker-intersystems/intersystems/iris-community:2026.3.0AI.154.0 signalnoir/iris-aihub-community:2026.3.0AI.154.0
   ```

3. Optional, for real Agent calls: create `.env` in the repo root (git-ignored), with your own key:

   ```text
   SN_AI_PROVIDER=openai
   SN_AI_MODEL=gpt-4o-mini
   SN_AI_API_KEY=sk-...
   ```

## Every time

```sh
sh dev/aihub/up.sh build   # after Dockerfile changes only
sh dev/aihub/up.sh up      # container signalnoir-iris, http://localhost:52773
sh dev/aihub/up.sh down
```

The `.env` is read only when the container is created: after editing it, run `down` then `up`.

Compile and test through iris-agentic-dev (repo mounted at `/home/irisowner/dev`):

```sh
iris-agentic-dev compile --container signalnoir-iris -n IRISAPP --format json $(find src tests -name '*.cls')
iris-agentic-dev exec --container signalnoir-iris -n IRISAPP 'set ^UnitTestRoot="/home/irisowner/dev/tests" do ##class(%UnitTest.Manager).RunTest("SignalNoir","/noload/nodelete/recursive")'
```

On a fresh container, compile twice (class order). Use `--format json`: a refused document (for
example `CodeMode = expression`, blocked by iris-agentic-dev) is easy to miss in text mode.

## Rules

- Never push this image or one derived from it to any registry (Constitution, Platform Constraints).
- Keys enter only at runtime (`.env`); never in an image layer, commit, Timeline or log.
- With `.env` present, the suite calls the real model (a few tokens per run).

# Signal Noir submission image (feature 012), on top of the AI Hub EAP build 154. Locally,
# docker-compose.yml passes IMAGE: the build the operator loads with `docker load` and retags, never
# pulled from or pushed to a registry. Use the default Docker builder: a docker-container driver
# cannot see the local base image. No secret is read at build time.
# The default is the build 154 image InterSystems DevCloud can pull (private to its builder), for the
# online demo, which builds this Dockerfile with no arguments.
ARG IMAGE=europe-west2-docker.pkg.dev/iris-community-demos/community/iris-community:2026.3.0AI.154.0

# The operator console, built with a pinned Node so the installer needs no front-end toolchain
FROM node:22.17.0-bookworm-slim AS console
WORKDIR /ui
COPY ui/package.json ui/package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY ui/ ./
RUN npm run build

FROM $IMAGE
USER root
RUN mkdir -p /data/IRISAPP_DATA/irisapp_dataenstemp /data/IRISAPP_DATA/irisapp_datasecondary && \
    chown -R irisowner:irisowner /data
USER irisowner
WORKDIR /home/irisowner/dev
COPY --chown=irisowner:irisowner merge.cpf ./
COPY --chown=irisowner:irisowner boot/ ./boot/
COPY --chown=irisowner:irisowner src/ ./src/
COPY --chown=irisowner:irisowner deploy/install.script ./deploy/
COPY --from=console --chown=irisowner:irisowner /ui/build/ ./ui/build/
# The non-secret settings of .env.example, for a run with no .env (DevCloud); a .env overrides them.
# The provider key is never set here: without one, Cases go to review with that reason.
ENV SN_SIM_BASE_URL=http://localhost:52773/sim/api/v1 \
    SN_BACKGROUND_TASKS=1
RUN iris start IRIS && \
    iris merge IRIS /home/irisowner/dev/merge.cpf && \
    iris session IRIS < /home/irisowner/dev/deploy/install.script && \
    iris stop IRIS quietly

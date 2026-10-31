# Signal Noir submission image (feature 012). Built locally on top of the AI Hub EAP build 154,
# which the operator loads with `docker load` and retags; it is never pulled from or pushed to a
# registry, and neither is this image. Use the default Docker builder: a docker-container driver
# cannot see the local base image. No secret is read at build time.
ARG IMAGE=signalnoir/iris-aihub:2026.3.0AI.154.0

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
RUN iris start IRIS && \
    iris merge IRIS /home/irisowner/dev/merge.cpf && \
    iris session IRIS < /home/irisowner/dev/deploy/install.script && \
    iris stop IRIS quietly

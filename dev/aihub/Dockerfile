# Dev-only image over the AI Hub EAP build 154 (Community edition, ARM64 native). Never pushed anywhere
# (Constitution: no EAP image or derived image goes to a registry). No license key is needed: the
# Community edition carries its own license and private web server.
ARG IMAGE=signalnoir/iris-aihub-community:2026.3.0AI.154.0
FROM $IMAGE

USER root
RUN mkdir -p /data/IRISAPP_DATA/irisapp_dataenstemp /data/IRISAPP_DATA/irisapp_datasecondary && \
    chown -R irisowner:irisowner /data
USER irisowner
WORKDIR /home/irisowner/dev

RUN --mount=type=bind,src=.,dst=/home/irisowner/dev \
    iris start IRIS && \
    iris merge IRIS /home/irisowner/dev/merge.cpf && \
    iris session IRIS < /home/irisowner/dev/dev/aihub/setup.script && \
    iris stop IRIS quietly

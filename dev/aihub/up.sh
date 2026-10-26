#!/bin/sh
# Dev environment on IRIS AI Hub EAP build 154 (Community, ARM64 native). Run from the repo root.
# Dev only: the official image, compose and README belong to feature 012.
# Needs the image loaded and tagged as signalnoir/iris-aihub-community:2026.3.0AI.154.0 and an
# optional ./.env (SN_AI_PROVIDER, SN_AI_MODEL, SN_AI_API_KEY), read only at runtime.
#   sh dev/aihub/up.sh build   # build the dev image signalnoir-dev:154c
#   sh dev/aihub/up.sh up      # start signalnoir-iris; web on http://localhost:52773
#   sh dev/aihub/up.sh down    # stop and remove the container
set -e
case "$1" in
build)
	docker build -f dev/aihub/Dockerfile -t signalnoir-dev:154c .
	;;
up)
	ENVFILE=""
	[ -f .env ] && ENVFILE="--env-file .env"
	docker run -d --name signalnoir-iris $ENVFILE \
		-e ISC_CPF_MERGE_FILE=/home/irisowner/dev/merge.cpf \
		-v "$PWD":/home/irisowner/dev \
		-p 1972:1972 -p 52773:52773 signalnoir-dev:154c
	;;
down)
	docker rm -f signalnoir-iris 2>/dev/null || true
	;;
*)
	echo "usage: sh dev/aihub/up.sh build|up|down"
	exit 1
	;;
esac

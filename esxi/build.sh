#!/usr/bin/env bash

SECRETS_FILE="/tmp/cache/secrets.pkrvar.hcl"
DISTRO_FILE="./json/distro.json"
HOST_FILE="./json/host.json"
ESXI_FILE="./json/esxi.json"

mkdir -p "$(dirname "${SECRETS_FILE}")"
cat << EOF > $SECRETS_FILE
esxi_username = "${ESXI_USERNAME}"
esxi_password = "${ESXI_PASSWORD}"
EOF
packer build \
	-var-file="${SECRETS_FILE}" \
	-var-file="${DISTRO_FILE}" \
	-var-file="${ESXI_FILE}" \
	-var-file="${HOST_FILE}" \
	esxi.pkr.hcl \
	&& rm $SECRETS_FILE
#!/usr/bin/env bash

if [ -z "$1" ] ;then
	echo
	echo "Usage: ./build.sh <vm_name>"
	echo
	echo "       e.g.: ./build.sh my-kubelet 17"
	echo
	exit 1
fi

function main {
	local vm_name="$1"

	DISTRO_FILE="./json/distro.json"
	HOST_FILE="./json/host.json"
	CREDENTIALS_FILE="./json/credentials.json"

	PACKER_LOG=1 \
	PACKER_LOG_PATH="./log/packer.log" \
	packer build \
		-var-file="${CREDENTIALS_FILE}" \
		-var-file="${DISTRO_FILE}" \
		-var-file="${HOST_FILE}" \
		-var=vm_name="${vm_name}" \
		tart.pkr.hcl
}

main "$@"


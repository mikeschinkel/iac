#!/usr/bin/env bash
set -eo pipefail

DOWNLOAD_URL="https://github.com/mikefarah/yq/releases/latest/download/yq_linux_arm64"
LOCAL_BIN="/usr/local/bin/yq"

function install_yq {
	curl -L "${DOWNLOAD_URL}" -o "${LOCAL_BIN}" \
		&& chmod +x "${LOCAL_BIN}" \
		&& yq --version
}

if ! install_yq ; then
	echo "ERROR: Unable to install yq" >&2
	exit 1
fi
echo
echo "SUCCESS! yq installed."
echo

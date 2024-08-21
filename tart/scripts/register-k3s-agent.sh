#!/usr/bin/env bash
set -x

K3S_DOMAIN="$1"
K3S_TOKEN="${K3S_TOKEN:-"$2"}"
K3S_URL="${K3S_URL:-"${K3S_DOMAIN}:6443"}"
K3S_DOWNLOAD="https://get.k3s.io"
K3S_INSTALL="/tmp/install-k3s.sh"

function log_error {
	local message="$1"
	echo "ERROR: ${message}" >&2
}

function main {
	echo "Downloading K3s install script from ${K3S_DOWNLOAD} to ${K3S_INSTALL}"
	if ! curl -sfL "${K3S_DOWNLOAD}" > "${K3S_INSTALL}" ; then
		log_error "Failed to download ${K3S_DOWNLOAD} to ${K3S_INSTALL}"
		return 1
	fi
	if ! sh "${K3S_INSTALL}" ; then
		log_error "Failed to install K3s."
		return 1
	fi
	return 0
}

main "$@" || exit 1
echo
echo "SUCCESS! K3s agent registered."
echo




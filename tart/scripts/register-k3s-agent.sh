#!/usr/bin/env bash
set -x

K3S_DOMAIN="$1"
K3S_DOWNLOAD="https://get.k3s.io"
K3S_INSTALL="/tmp/install-k3s.sh"
AGENT_SERVICE="/etc/systemd/system/k3s-agent.service"

K3S_TOKEN="${K3S_TOKEN:-"$2"}"
K3S_URL="${K3S_URL:-"https://${K3S_DOMAIN}:6443"}"

K3S_URL_ENV="K3S_URL=${K3S_URL}"
K3S_TOKEN_ENV="K3S_TOKEN=${K3S_TOKEN}"

function log_error {
	local message="$1"
	echo "ERROR: ${message}" >&2
}

function install_agent {
	chmod +x "${K3S_INSTALL}"
	K3S_TOKEN="${K3S_TOKEN}" \
	K3S_URL="${K3S_URL}" \
		sh "${K3S_INSTALL}"
}

function update_agent_service {
	local envs=("${K3S_URL_ENV}" "${K3S_TOKEN_ENV}")
	echo "Adding environment vars to k3s-agent service."
	for env in "${envs[@]}"; do
		# Use sed to insert the lines after [Service]
		sudo sed -i "/\[Service\]/a\Environment=\"${env}\"" "${AGENT_SERVICE}"
	done
	sudo systemctl daemon-reload
	sudo systemctl restart k3s-agent
	echo "Environment vars added to k3s-agent service."
}

function main {
	echo "Downloading K3s install script from ${K3S_DOWNLOAD} to ${K3S_INSTALL}"
	if ! curl -sfL "${K3S_DOWNLOAD}" 1> "${K3S_INSTALL}" ; then
		log_error "Failed to download ${K3S_DOWNLOAD} to ${K3S_INSTALL}"
		return 1
	fi
	echo "Running K3s agent install script"
	if ! install_agent ; then
		log_error "Failed to install K3s."
		return 1
	fi
	echo "Update K3s agent service to connect to ${K3S_URL_ENV}"
	if ! update_agent_service ; then
		log_error "Failed to update agent service"
		return 1
	fi
	echo "Make ~/.kube directory for K3s config"
	if ! mkdir -p ~/.kube ; then
		log_error "Failed to make directory ${HOME}/.kube."
		return 1
	fi
	return 0
}

main "$@" || exit 1
echo
echo "SUCCESS! K3s agent registered."
echo




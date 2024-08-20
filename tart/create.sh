#!/usr/bin/env bash

function get_control_plane_token {
	local node="$1"
	local password="$2"

	sshpass -p"${password}" ssh "admin@${node}.local" "sudo cat /var/lib/rancher/k3s/server/node-token"
}

function get_register_agent_node_cmd {
	local k3s="$1"
	local token="$2"

	printf "curl -sfL %s | K3S_URL=%s:6443 K3S_TOKEN=%s sh -" "https://get.k3s.io" "${k3s}" "${token}"
}
function register_agent_node {
	local control_plane="$1"
	local node="$2"
	local password="$3"

	local agent="${node}.local"
	local k3s="https://${control_plane}.local"
	local token
	local uninstall="/usr/local/bin/k3s-uninstall.sh"

	token="$(get_control_plane_token "${control_plane}" "${password}")"
	echo "Token: ${token}"
	if [ -f "${uninstall}" ]; then
		"${uninstall}"
	fi
	get_register_agent_node_cmd "${k3s}" "${token}"
	sshpass -p"${password}" ssh "admin@${agent}" "$(get_register_agent_node_cmd "${k3s}" "${token}")"
}

function main {
	local k1="$1"
	local password
	local error=0

	shift
	read -r -s -p "Password: " password
	printf "\n\nCreating K3s cluster for control plane '%s'\n" "${k1}"
	for k in "$@" ; do
		printf "\n— Registering agent node '%s'\n" "${k}"
		if ! register_agent_node "${k1}" "${k}" "${password}" ; then
			echo "Failed to register node '${k}'"
			error=1
		fi
	done
	if [ $error -eq 1 ]; then
		exit 1
	fi
	printf "\nCluster creation complete.\n"
}

main k1 k2 k3

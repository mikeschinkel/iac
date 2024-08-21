#!/usr/bin/env bash
set -x

K3S_DOMAIN="$1"
K3S_TOKEN="${K3S_TOKEN:-"$2"}"
K3S_URL="${K3S_URL:-"https://${K3S_DOMAIN}:6443"}"

K3S_YAML_FILE="k3s.yaml"
SERVER_CERT_FILE="server-ca.crt"
CLIENT_CERT_FILE="client-admin.crt"
CLIENT_KEY_FILE="client-admin.key"

CERT_DIR="/var/lib/rancher/k3s/server/tls"
K3S_YAML="/etc/rancher/k3s/${K3S_YAML_FILE}"
SERVER_CERT="${CERT_DIR}/${SERVER_CERT_FILE}"
CLIENT_CERT="${CERT_DIR}/${CLIENT_CERT_FILE}"
CLIENT_KEY="${CERT_DIR}/${CLIENT_KEY_FILE}"
FILEPATHS=("${K3S_YAML}" "${SERVER_CERT}" "${CLIENT_CERT}" "${CLIENT_KEY}")

CLUSTERS=".clusters[].cluster"
USERS=".users[].user"
PARENTS=( "${CLUSTERS}" "${CLUSTERS}" "${USERS}" "${USERS}")
PROPS=("server" "certificate-authority-data" "client-certificate-data" "client-key-data")

function log_error {
	local message="$1"
	echo "ERROR: ${message}" >&2
}

function yq_eval {
	local expr="$1"
	local value="$2"
	# ${expr%%=*} means output just the property but not the value
	echo "Updating ${expr%%=*} in ${K3S_YAML} to ${value}"
	sudo yq e "${expr}" -i "${K3S_YAML}"
}

function configure_master {
	local index=0
	local value

	echo "Updating K3s config file ${K3S_YAML}."
	for prop in "${PROPS[@]}"; do
		if [ $index -eq 0 ]; then
			value="${K3S_URL}"
			proxy="${value}"
		else
			value="$(sudo base64 --wrap=0 "${FILEPATHS[index]}")"
			proxy="${FILEPATHS[index]}"
		fi
		yq_eval \
			"$(printf '%s.%s = "%s"' "${PARENTS[index]}" "${prop}" "${value}")" \
			"${proxy}"
		index=$(( index+1 ))
	done

	kubectl delete node debian || true

	echo "K3s config file updated"
}

function main {
	echo "Configuring K3s master"
	if ! configure_master ; then
		log_error "Failed to configure K3s master."
		return 1
	fi
	return 0
}

main "$@" || exit 1
echo
echo "SUCCESS! K3s master configured."
echo




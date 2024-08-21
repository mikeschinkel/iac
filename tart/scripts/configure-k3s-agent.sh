#!/usr/bin/env bash
set -x

K3S_MASTER="$1"
K3S_WORKER="$2"
K3S_URL="https://${K3S_MASTER}:6443"

K3S_YAML="/etc/rancher/k3s/k3s.yaml"

function log_error {
	local message="$1"
	echo "ERROR: ${message}" >&2
}

function update_k3s_config {
	local clusters=".clusters[].cluster"
	local users=".users[].user"
	local server_dir="/var/lib/rancher/k3s/server/tls"
	expr="$(printf '%s.server = "%s"' "${clusters}" "${K3S_URL}")" \
		&& yq e "${expr}" -i "${K3S_YAML}" \
	&& expr="$(printf '%s.certificate-authority = "%s/server-ca.crt"' "${clusters}" "${server_dir}")" \
		&& yq e "${expr}" -i "${K3S_YAML}" \
	&& expr="$(printf '%s |= del(.certificate-authority-data)' "${clusters}")" \
		&& yq e "${expr}" -i "${K3S_YAML}" \
	&& expr="$(printf '%s |= del(.client.certificate-data)' "${users}")" \
		&& yq e "${expr}" -i "${K3S_YAML}" \
	&& expr="$(printf '%s |= del(.client-key-data)' "${users}")" \
		&& yq e "${expr}" -i "${K3S_YAML}" \
	&& expr="$(printf '%s.client-certificate = "%s/client-admin.crt"' "${users}" "${server_dir}")" \
		&& yq e "${expr}" -i "${K3S_YAML}" \
	&& expr="$(printf '%s.client-key = "%s/client-admin.key"' "${users}" "${server_dir}")" \
		&& yq e "${expr}" -i "${K3S_YAML}"
}

function configure_agent {
	echo "Chmod-ing ${K3S_YAML} to 644"
	if ! sudo chmod 644 "${K3S_YAML}"; then
		log_error "Failed to chmod ${K3S_YAML} on ${K3S_WORKER} to 644"
		return 1
	fi
	if ! update_k3s_config; then
		log_error "Failed to update ${K3S_YAML} on ${K3S_WORKER} with server ${K3S_MASTER}"
		return 1
	fi
	return 0
}

configure_agent "$@" || exit 1
echo
echo "SUCCESS! K3s agent configured."
echo




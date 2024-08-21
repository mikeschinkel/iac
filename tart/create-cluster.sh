#!/usr/bin/env bash
set -eo pipefail

DEFAULT_USERNAME="admin"
DEFAULT_PASSWORD="admin"

HOST_PATH="./config"
REMOTE_KUBECONFIG="/etc/rancher/k3s/k3s.yaml"
LOCAL_KUBECONFIG="${HOST_PATH}/k3s.yaml"

function log_error {
	local message="$1"
	echo "ERROR: ${message}" >&2
}

function do_ssh {
	local node="$1"
	local username="$2"
	local password="$3"
	local command="$4"
	local result=0
	local temp_file
	temp_file="$(mktemp)"

	if [[ "${node}" != *.local ]]; then
		node="${node}.local"
	fi

	if ! sshpass -p"${password}" \
		ssh \
			-o StrictHostKeyChecking=no \
			-o UserKnownHostsFile=/dev/null \
			"${username}@${node}" \
			"sudo ${command}" 2>"${temp_file}"; then
				result=1
	fi
	if [ $result -eq 1 ] ; then
		# Output any non-warnings
		awk '!/Warning:/' "${temp_file}"
	fi
	rm -rf "${temp_file}"
	return $result
}

function do_scp {
	local password="$1"
	local from_file="$2"
	local to_file="$3"
	local result=0
	local temp_file
	temp_file="$(mktemp)"

	if ! sshpass -p"${password}" \
		scp \
			-o StrictHostKeyChecking=no \
			-o UserKnownHostsFile=/dev/null \
			"${from_file}" \
			"${to_file}" 2>"${temp_file}"; then
			result=1
	fi
	if [ $result -eq 1 ] ; then
		# Output any non-warnings
		awk '!/Warning:/' "${temp_file}"
	fi
	rm -rf "${temp_file}"
	return $result
}

function get_control_plane_token {
	local node="$1"
	local username="$2"
	local password="$3"

	do_ssh \
		"${node}" \
		"${username}" \
		"${password}" \
		"cat /var/lib/rancher/k3s/server/node-token"
}

function yq_eval {
	local expr="$1"
	yq e "${expr}" -i "${LOCAL_KUBECONFIG}"
}

function update_k3s_config {
	local server="$1"
	local server_url="https://${server}:6443"

	local clusters=".clusters[].cluster"
	local users=".users[].user"
	local server_dir="/var/lib/rancher/k3s/server/tls"

	yq_eval "$(printf '%s.server = "%s"' "${clusters}" "${server_url}")" \
		&& yq_eval "$(printf '%s.certificate-authority = "%s/server-ca.crt"' "${clusters}" "${server_dir}")" \
		&& yq_eval "$(printf '%s |= del(.certificate-authority-data)' "${clusters}")" \
		&& yq_eval "$(printf '%s |= del(.client.certificate-data)' "${users}")" \
		&& yq_eval "$(printf '%s |= del(.client-key-data)' "${users}")" \
		&& yq_eval "$(printf '%s.client-certificate = "%s/client-admin.crt"' "${users}" "${server_dir}")" \
		&& yq_eval "$(printf '%s.client-key = "%s/client-admin.key"' "${users}" "${server_dir}")"
}

function make_node_dir_cmds {
	local username="$1"
	local password="$2"
	local config_dir="$3"

	printf "mkdir -p '%s'" "${config_dir}"
	printf " && sudo chown '%s:%s' '%s'" "${username}" "${username}" "${config_dir}"
	printf " && sudo chmod 700 '%s'" "${config_dir}"
}

function configure_master_node {
	local control_plane="$1"
	local username="$2"
	local password="$3"
	local remote_kubeconfig
	local master_domain="${control_plane}.local"

  echo "Download kubeconfig from ${master_domain} to host"
	remote_kubeconfig="${username}@${master_domain}:${REMOTE_KUBECONFIG}"
  if ! do_scp "${password}" "${remote_kubeconfig}" "${LOCAL_KUBECONFIG}"; then
		log_error "Failed to scp from ${remote_kubeconfig} to ${LOCAL_KUBECONFIG}"
		return 1
  fi

  echo "Modify the .server property in the kubeconfig file to use ${master_domain}"
  if ! update_k3s_config "${master_domain}" ; then
		log_error "Failed to update ${LOCAL_KUBECONFIG} with yq"
		return 1
	fi

  echo "Upload kubeconfig from host to ${master_domain}"
  if ! do_scp "${password}" "${LOCAL_KUBECONFIG}" "${remote_kubeconfig}"; then
		log_error "Failed to scp from ${LOCAL_KUBECONFIG} to ${remote_kubeconfig}"
		return 1
  fi

}

function register_agent_node {
	local control_plane="$1"
	local node="$2"
	local username="$3"
	local password="$4"
	shift;shift;shift;shift

	local master_domain="${control_plane}.local"
	local register_agent="register-k3s-agent.sh"
	local register_agent_path="./scripts/${register_agent}"
	local scripts_dir="/home/${username}/scripts"
	local remote_script_root="${username}@${node}.local:${scripts_dir}"
	local remote_script
	local uninstall="/usr/local/bin/k3s-uninstall.sh"
	local token
	local home_dir="/home/${username}"
	local config_dir="${home_dir}/.kube"
	local configure_agent="configure-k3s-agent.sh"
	local configure_agent_path="./scripts/${configure_agent}"
	local kube_config="KUBECONFIG=${config_dir}/config"
	local label_cmd

	token="$(get_control_plane_token "${control_plane}" "${username}" "${password}")"
	echo "Token: ${token}"
	if [ -f "${uninstall}" ]; then
		"${uninstall}"
	fi

  echo "Upload registration script ${register_agent} to ${node}.local agent"
	remote_script="${remote_script_root}/${register_agent}"
  if ! do_scp "${password}" "${register_agent_path}" "${remote_script}"; then
		log_error "Failed to scp from ${register_agent_path} to ${remote_script}"
		return 1
  fi

  echo "Register agent node '${node}' for ${username}"
	if ! do_ssh "${node}" "${username}" "${password}" "${scripts_dir}/${register_agent} '${master_domain}' '${token}'"; then
			log_error "Failed to register agent node '${node}' for ${username}"
			return 1
	fi


	echo "Creating K3s cluster for control plane '${k1}'"


  echo "Copy k3s configure agent script ${configure_agent} to ${node} agent"
	remote_script="${remote_script_root}/${configure_agent}"
  if ! do_scp "${password}" "${configure_agent_path}" "${remote_script}"; then
		log_error "Failed to scp from ${configure_agent_path} to ${remote_script}"
		return 1
  fi

  echo "Configure agent node '${node}' for ${username}"
	if ! do_ssh "${node}" "${username}" "${password}" "${scripts_dir}/${configure_agent} '${master_domain}' '${node}'"; then
			log_error "Failed to configure agent node '${node}' for ${username}"
			return 1
	fi

	echo "Labeling ${node} as 'worker' node"
	label_cmd="${kube_config} kubectl label node ${node} node-role.kubernetes.io/worker=worker"
	echo "LABEL_CMD: ${label_cmd}"
	if ! do_ssh "${node}" "${username}" "${password}" "${label_cmd}" ; then
		log_error "Failed to label ${node} as 'worker' node"
		return 1
	fi

	echo "Verify the setup by listing nodes on ${node}"
	get_nodes_cmd="${kube_config} kubectl get nodes"
	if ! do_ssh "${node}" "${username}" "${password}" "${get_nodes_cmd}" ; then
		log_error "Failed to verify the setup on ${node}"
		return 1
	fi

	return 0
}

function main {
	local k1="$1"
	shift

	local master="${k1}.local"
	local username
	local password

	read -r -s -p "Username: " username
	if [ -z "${username}" ]; then
		username="${DEFAULT_USERNAME}"
	fi
	read -r -s -p "Password: " password
	if [ -z "${password}" ]; then
		password="${DEFAULT_PASSWORD}"
	fi
	echo "Configuring K3s cluster control plane '${master}'"
	if ! configure_master_node "${k1}" "${username}" "${password}" ; then
			echo "Failed to configure master node '${master}'"
			return 1
	fi
	for k in "$@" ; do
		echo "Registering node '${k}'"
		if ! register_agent_node "${k1}" "${k}" "${username}" "${password}" ; then
			echo "Failed to register node '${k}.local'"
			return 1
		fi
	done
	printf "\nCluster creation complete.\n"
}

case "$1" in
	k2)
		main k1 k2
		;;
	k3)
		main k1 k3
		;;
	*)
		main k1 k2 k3
		;;
esac


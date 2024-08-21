#!/usr/bin/env bash
set -eo pipefail

DEFAULT_USERNAME="admin"
DEFAULT_PASSWORD="admin"
UNINSTALL="/usr/local/bin/k3s-UNINSTALL.sh"
MASTER_K3S_YAML="/etc/rancher/k3s/k3s.yaml"
NODE_K3S_YAML_PATH=".kube/config"
HOST_K3S_YAML="config/k3s.yaml"

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

function get_master_token {
	local node="$1"
	local username="$2"
	local password="$3"

	do_ssh \
		"${node}" \
		"${username}" \
		"${password}" \
		"cat /var/lib/rancher/k3s/server/node-token"
}

function make_node_dir_cmds {
	local username="$1"
	local password="$2"
	local config_dir="$3"

	printf "mkdir -p '%s'" "${config_dir}"
	printf " && sudo chown '%s:%s' '%s'" "${username}" "${username}" "${config_dir}"
	printf " && sudo chmod 700 '%s'" "${config_dir}"
}

function register_master {
	local master="$1"
	local username="$2"
	local password="$3"

	local master_domain="${master}.local"
	local register_master="register-k3s-master.sh"
	local register_master_path="./scripts/${register_master}"
	local scripts_dir="/home/${username}/scripts"
	local remote_script_root="${username}@${master_domain}:${scripts_dir}"
	local remote_script
	local token

  echo "Upload master registration script ${register_master} to ${master_domain}"
	remote_script="${remote_script_root}/${register_master}"
  if ! do_scp "${password}" "${register_master_path}" "${remote_script}"; then
		log_error "Failed to scp from ${register_master_path} to ${remote_script}"
		return 1
  fi

	token="$(get_master_token "${master}" "${username}" "${password}")"
  echo "Register master '${master_domain}' for ${username}"
	if ! do_ssh "${master}" "${username}" "${password}" "${scripts_dir}/${register_master} '${master_domain}' '${token}'"; then
			log_error "Failed to register master '${master}' for ${username}"
			return 1
	fi

	echo "Verify the setup by listing nodes on ${master_domain}"
	get_nodes_cmd="kubectl get nodes"
	if ! do_ssh "${master_domain}" "${username}" "${password}" "${get_nodes_cmd}" ; then
		log_error "Failed to verify the setup on ${master_domain}"
		return 1
	fi

	return 0
}

function register_agent_node {
	local master="$1"
	local node="$2"
	local username="$3"
	local password="$4"
	shift;shift;shift;shift

	local master_domain="${master}.local"
	local register_agent="register-k3s-agent.sh"
	local register_agent_path="./scripts/${register_agent}"
	local scripts_dir="/home/${username}/scripts"
	local remote_master_addr="${username}@${master}.local"
	local remote_node_addr="${username}@${node}.local"
	local remote_script_root="${remote_node_addr}:${scripts_dir}"
	local remote_script
	local token
	local label_cmd
	local node_k3s_yaml="/home/${username}/${NODE_K3S_YAML_PATH}"

	token="$(get_master_token "${master}" "${username}" "${password}")"
	if [ -f "${UNINSTALL}" ]; then
		"${UNINSTALL}"
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

  echo "Download kubeconfig ${MASTER_K3S_YAML} from master ${remote_master_addr} to ${HOST_K3S_YAML} on host"
	master_config="${remote_master_addr}:${MASTER_K3S_YAML}"
  if ! do_scp "${password}" "${master_config}" "${HOST_K3S_YAML}"; then
		log_error "Failed to scp from ${master_config} to ${HOST_K3S_YAML}"
		return 1
  fi

  echo "Ensure empty ~/.kube directory on agent node ${node}"
	if ! do_ssh "${node}" "${username}" "${password}" "rm -rf ~/.kube && mkdir -p ~/.kube"; then
			log_error "Failed to register agent node '${node}' for ${username}"
			return 1
	fi

    echo "Upload kubeconfig ${HOST_K3S_YAML} on host to agent node ${node_k3s_yaml}"
	node_config="${remote_node_addr}:${node_k3s_yaml}"
  if ! do_scp "${password}" "${HOST_K3S_YAML}" "${node_config}"; then
		log_error "Failed to scp from ${HOST_K3S_YAML} to ${node_config}"
		return 1
  fi

	echo "Labeling ${node} as 'worker' node"
	label_cmd="kubectl label node ${node} node-role.kubernetes.io/worker=worker"
	if ! do_ssh "${master}" "${username}" "${password}" "${label_cmd}" ; then
		log_error "Failed to label ${node} as 'worker' node"
		return 1
	fi

	echo "Verify the ${node} setup by listing nodes"
	get_nodes_cmd="kubectl get nodes"
	if ! do_ssh "${master}" "${username}" "${password}" "${get_nodes_cmd}" ; then
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
		printf "\n"
	fi

	read -r -s -p "Password: " password
	if [ -z "${password}" ]; then
		password="${DEFAULT_PASSWORD}"
		printf "\n"
	fi

	echo "Registering master '${k1}'"
	if ! register_master "${k1}" "${username}" "${password}" ; then
		echo "Failed to register master '${master}'"
		return 1
	fi

	echo "Configuring K3s agents nodes '$*' for '${master}'"
	for k in "$@" ; do
		echo "Registering agent node '${k}'"
		if ! register_agent_node "${k1}" "${k}" "${username}" "${password}" ; then
			echo "Failed to register agent node '${k}.local'"
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


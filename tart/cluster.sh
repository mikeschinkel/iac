#!/bin/bash
set -eo pipefail

DEFAULT_USERNAME="admin"
DEFAULT_PASSWORD="admin"
UNINSTALL="/usr/local/bin/k3s-UNINSTALL.sh"
MASTER_K3S_YAML="/etc/rancher/k3s/k3s.yaml"
NODE_K3S_YAML_PATH=".kube/config"
HOST_K3S_YAML="config/k3s.yaml"
VMS=("k1" "k2" "k3")

usage() {
	local command="$1"
	{
		case "${command}" in
			configure)
				echo "  Usage: ./cluster.sh configure [k2|k3]"
				;;
			start)
				echo "  Usage: ./cluster.sh start [--with-console]"
				;;
			restart)
				echo "  Usage: ./cluster.sh restart [--with-console]"
				;;
			*)
				echo "  Usage: ./cluster.sh <command>"
				echo
				echo "      <command> may be one of:"
				echo "      	- configure [k2|k3]"
				echo "      	- build"
				echo "      	- start [--with-console]"
				echo "      	- list"
				echo "      	- stop"
				echo "      	- renew"
				echo "      	- restart [--with-console]"
				echo "      	- delete"
				;;
		esac
		echo
		echo "  ./cluster.sh manages three (3) VMs; k1, k2 and k3."
	} >&2
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

configure_cluster() {
	local nodes=()
	local master="k1"
	local master_domain="${master}.local"
	local username="${DEFAULT_USERNAME}"
	local password="${DEFAULT_PASSWORD}"
	case "$1" in
		k2)
			nodes=("k2")
			;;
		k3)
			nodes=("k3")
			;;
		*)
			nodes=("k2" "k3")
			;;
	esac

	echo "Registering master '${master}'"
	if ! register_master "${master}" "${username}" "${password}" ; then
		echo "Failed to register master '${master_domain}'"
		return 1
	fi

	echo "Configuring K3s agents nodes '$*' for '${master_domain}'"
	for node in "${nodes[@]}" ; do
		echo "Registering agent node '${node}'"
		if ! register_agent_node "${master}" "${node}" "${username}" "${password}" ; then
			echo "Failed to register agent node '${node}.local'"
			return 1
		fi
	done
	printf "\nCluster creation complete.\n"
}

list_cluster() {
	echo
	echo "Cluster VMs:"
	printf "Name  Status\n"
	tart list | awk '$2 ~ /^k[1-3]/ {print $2 "    " $6}'
	echo
}

build_vm() {
	local vm_name="$1"

	if ! [ -f ./build-vm.sh ] ; then
		log_error "./build.sh not found."
		return 1
	fi
	./build-vm.sh "${vm_name}"
}

build_all_vms() {
	local vm
	for vm in "${VMS[@]}"; do
		if ! build_vm "${vm}"; then
			log_error "Failed to build VM ${vm}"
			return 1
		fi
	done
}

build_cluster() {
	local result=0
	echo "Building K3s cluster (k1, k2, k3)"
	if ! build_all_vms; then
		log_error "Failed to build one or more VMs in cluster"
		result=1
	else
		echo "K3s cluster built."
	fi
	list_cluster
	return $result
}

run_all_vms() {
	local args=()
	local with_console=0
	local result=0
	local vm

	for arg in "$@" ; do
		if [ "${arg}" == "--with-console" ]; then
			with_console=1
			continue
		fi
		args+=("${k}")
	done
	if [ $with_console -eq 0 ]; then
		args+=("--no-graphics")
	fi

	for vm in "${VMS[@]}"; do
		echo "Starting VM '${vm_name}'..."
		if ! _run_vm "${vm}" "${args[@]}"; then
			log_error "Failed to start VM ${vm}"
			result=1
		else
			sleep 1
		fi
	done
	return $result
}

_run_vm() {
	local vm_name="$1"
	shift
	# args="$@"
	tart run "${vm_name}" \
		--net-bridged=en0 \
		"$@" \
		&
}

start_cluster() {
	local result=0
	# args="$@"

	echo "Starting K3s cluster w/k1, k2, and k3..."
	if ! run_all_vms "$@" ; then
		log_error "Failed to start one or more VMs in cluster" "$*"
		result=1
	else
		echo "K3s cluster started"
		sleep 3
	fi
	list_cluster
	return $result
}

stop_cluster() {
	echo "Stopping K3s cluster (k1, k2, k3)"
	list_cluster
	tart stop k1
	tart stop k2
	tart stop k3
	list_cluster
	echo "K3s cluster stopped."
}

function stop_delete_vm {
	local vm_name="$1"
	local result=0

	echo "Stopping ${vm_name}..."
	if ! tart stop "${vm_name}"; then 
		echo "The VM '${vm_name}' failed to stop." >&2
		result=1
	else
		echo "VM stopped."
	fi
	echo "Deleting ${vm_name}..."
	if ! tart delete "${vm_name}"; then
		echo "The VM '${vm_name}' failed to delete." >&2
		result=1
	else
		echo "VM deleted."
	fi
	return $result
}

delete_all_vms() {
	local vm
	local result=0

	for vm in "${VMS[@]}"; do
		if ! stop_delete_vm "${vm}"; then
			echo "Failed to stop or delete VM '${vm}'"
			result=1
		fi
	done
	return $result
}

delete_cluster() {
	echo "Deleting K3s cluster (k1, k2, k3)"
	list_cluster
	if ! delete_all_vms ; then
		log_error "Unable to delete one or more VMs"
	fi
	echo
	echo "K3s cluster deleted."
	list_cluster
}

function restart_cluster {
	stop_cluster || echo
	start_cluster "$@"
}

function node_count {
	tart list \
		| awk '{print $2}' \
		| awk '/^k/' \
		| wc -l
}

function renew_cluster {
	delete_cluster
	if [ "$(node_count)" -ne 0 ] ; then
		log_error "Unable to delete all nodes in cluster"
		return 1
	fi
	if ! build_cluster ; then
		log_error "Unable to build all nodes in cluster"
		return 1
	fi
	if ! start_cluster ; then
		log_error "Unable to start all nodes in cluster"
		return 1
	fi
	if ! configure_cluster ; then
		log_error "Unable to configure cluster"
		return 1
	fi
	return 0
}

function log_error {
	local message="$1"
	echo "ERROR: ${message}" >&2
	echo "ERROR: ${message}" >> ./cluster.log
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

function main {
	local command="$1"
	shift
	case "${command}" in
		configure)
			if ! configure_cluster "$@"; then 
				usage configure
			fi
			;;
		build)
			if ! build_cluster "$@"; then 
      	usage build
      fi
			;;
		start)
			if ! start_cluster "$@"; then 
      	usage start
      fi
			;;
		stop)
			if ! stop_cluster; then 
				usage stop
			fi
			;;
		restart)
			if ! restart_cluster "$@"; then 
				usage restart
			fi
			;;
		renew)
			if ! renew_cluster "$@"; then 
      	usage renew
      fi
			;;
		list)
			list_cluster
			;;
		delete)
			if ! delete_cluster; then 
				usage delete
			fi
			;;
		*)
			usage "No command provided." "$@"
			;;
	esac
}
main "$@"

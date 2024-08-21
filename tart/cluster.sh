#!/bin/bash
set -eo pipefail

usage() {
	local message="$1"
	shift
	local command="$1"
	{
		echo
		echo "ERROR: ${message}"
		echo
		case "${command}" in
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
				echo "      	- build"
				echo "      	- start [--with-console]"
				echo "      	- list"
				echo "      	- stop"
				echo "      	- restart [--with-console]"
				echo "      	- delete"
				;;
		esac
		echo
		echo "  ./cluster.sh manages three (3) VMs; k1, k2 and k3."
	} >&2
	exit 1
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
		usage "./build.sh not found." "build", "${vm_name}"
	fi
	./build-vm.sh "${vm_name}"
}

build_all_vms() {
#	build_vm k1
	build_vm k1 \
		&& build_vm k2 \
		&& build_vm k3
}

build_cluster() {
	if ! [ -f ./build-vm.sh ] ; then
		echo "ERROR: ./build.sh not found in current directory." >&2
		usage
	fi
	echo "Building K3s cluster (k1, k2, k3)"
	if ! build_all_vms; then
		usage "Failed to build one or more VMs in cluster"
	fi	
	echo "K3s cluster built."
	list_cluster
}

run_all_vms() {
	local args=()
	local with_console=0

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

#	# shellcheck disable=SC2086
#	run_vm k1 "${args[@]}" \

	# shellcheck disable=SC2086
	run_vm k1 "${args[@]}" \
		&& run_vm k2 "${args[@]}" \
		&& run_vm k3 "${args[@]}"
}

run_vm() {
	local vm_name="$1"
	shift
	# args="$@"
	echo "Starting VM '${vm_name}'..."
	tart run "${vm_name}" \
		--net-bridged=en0 \
		"$@" \
		&

	sleep 1
}

start_cluster() {
	# args="$@"

	echo "Starting K3s cluster w/k1, k2, and k3..."
	if ! run_all_vms "$@" ; then
		usage "Failed to start one or more VMs in cluster" "$*"
	fi
	sleep 3
	list_cluster
	echo "K3s cluster started"
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
	if ! stop_delete_vm k1; then
		echo "Failed to stop/delete VM 'k1'"
	fi
	if ! stop_delete_vm k2; then
		echo "Failed to stop/delete VM 'k2'"
	fi
	if ! stop_delete_vm k3; then
		echo "Failed to stop/delete VM 'k3'"
	fi
}

delete_cluster() {
	echo "Deleting K3s cluster (k1, k2, k3)"
	list_cluster
	delete_all_vms
	echo
	echo "K3s cluster deleted."
	list_cluster
}

function restart_cluster {
	stop_cluster || echo
	start_cluster "$@"
}

function main {
	local command="$1"
	shift
	# args="$@"
	case "${command}" in
		list)
			list_cluster
			;;
		build)
			build_cluster "$@"
			;;
		start)
			start_cluster "$@"
			;;
		stop)
			stop_cluster
			;;
		restart)
			restart_cluster "$@"
			;;
		delete)
			delete_cluster
			;;
		*)
			usage "No command provided." "$@"
			;;
	esac
}
main "$@"

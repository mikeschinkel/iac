#!/usr/bin/env bash
set -eo pipefail

BIN_DIR="/usr/local/bin"
source "${BIN_DIR}/hosts-const.sh"

ERROR_LOG="${ERROR_LOG:-}"
ERROR_LOG_DIR="${ERROR_LOG_DIR:-}"
TMP_HOSTS="${TMP_HOSTS:-}"
HOSTS_FILE="${HOSTS_FILE:-}"
CURRENT_VM="${CURRENT_VM:-}"
VM_NAMES="${VM_NAMES:-}"

function get_hosts_entry {
	local vm_name="$1"
	avahi-resolve-host-name -4 "${vm_name}.local" \
		| awk '{print $2 "\t" $1}'
}

function now {
	date "+%Y-%m-%d %H:%M:%S"
}

function log_error {
	local message="$1"
	message="${message} at $(now)"
	echo "${message}" 1>&2
	echo "${message}" >> "${ERROR_LOG}"
}

function renew_dhcp_lease {
	echo "Renewing DHCP lease"
	if ! dhclient -r ; then
		log_error "Failed to flush DHCP"
		return 1
	fi

	if ! dhclient ; then
		log_error "Failed to renew DHCP"
		return 1
	fi

	if ! systemctl restart avahi-daemon ; then
		log_error "Failed to restart avahi-daemon"
		return 1
	fi
	echo "DHCP lease renewed"
	return 0
}

function has_host {
	local host="$1"
	#echo "Checking ${HOSTS_FILE} to see if it contains [${host}]"
	grep -E "\b${host}" "${HOSTS_FILE}" >/dev/null
}

function update_hosts {
	for vm_name in "${VM_NAMES[@]}"; do
		#echo "Checking VM '${vm_name}'"
		if [ "${vm_name}" == "${CURRENT_VM}" ]; then
			continue
		fi

		domain="${vm_name}.local"

		while true; do
			entry=$(get_hosts_entry "${vm_name}") || {
				if [ $once -eq 0 ] ; then
					# shellcheck disable=SC1090
					if ! renew_dhcp_lease; then
						log_error "Failed to renew DHCP lease"
						return 1
					fi
					once=1
					continue
				fi
			}
			if [ -n "${entry}" ] ; then
				break
			fi
			log_error "${domain} not found to be online"
			return 1
		done

		if has_host "${entry}"; then
			#echo "The hosts file already has this entry [${entry}]."
			continue
		fi

		if has_host "${domain}"; then
			echo "The hosts files has a different IP address for ${domain}. Remove existing entries and blank lines."
			awk "!/\b${domain}/ && NF" "${HOSTS_FILE}" | tee "${TMP_HOSTS}"
			echo "Replace /etc/hosts with updated file."
			mv "${TMP_HOSTS}" "${HOSTS_FILE}"
		fi

		if ! has_host "${domain}"; then
			echo "Add new entry in ${entry} /etc/hosts."
			printf "%s\n" "${entry}" | tee -a "${HOSTS_FILE}"
		fi

	done
}

function main {
	local vm_name
	local entry
	local domain
	local once=0

	mkdir -p "${ERROR_LOG_DIR}"

	# Ensure the DHCP lease is renewed
	if ! renew_dhcp_lease; then
		log_error "Failed to renew DHCP lease"
		return 1
	fi

	while update_hosts ; do
		# Check for updates every 5 seconds
		sleep 5
	done
	#If update_hosts fails it will allow the SystemD to capture it in the logs
	# but the Restart=always will kick-in and we'll restart the process again.
}
main "$@"


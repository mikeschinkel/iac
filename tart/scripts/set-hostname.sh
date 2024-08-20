#!/usr/bin/env bash
set -eo pipefail

# Set this instead: /var/lib/cloud/data/set-hostname

function main {
	local hostname="$1"

	echo "Setting hostname to '${hostname}'"
	echo "${hostname}" | sudo tee /etc/hostname > /dev/null
	printf "%s\t%s\t%s\n" 127.0.0.1 "${hostname}.local" "${hostname}" \
		| sudo tee -a /etc/hosts > /dev/null

}
main "$@" || exit 1
echo
echo "SUCCESS! Hostname set to: $1."
echo





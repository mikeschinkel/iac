#!/usr/bin/env bash
set -eo pipefail

function main {
	local prefix="^\s*#?\s*"
	local config="/etc/ssh/sshd_config"
	local permit="PermitRootLogin"
	local auth="PasswordAuthentication"
	local suffix="\s+(no|yes|prohibit-password)\s*$"

	if grep -E "${prefix}${permit}${suffix}" "${config}" > /dev/null; then
		sed -i -E "/${prefix}${permit}${suffix}/s/.*/${permit} yes/"  "${config}"
	else
		echo "${permit} yes" | tee -a "${config}" > /dev/null
	fi

	if grep -E "${prefix}${auth}${suffix}" "${config}"  > /dev/null ; then
		sed -i -E "/${prefix}${auth}${suffix}/s/.*/${permit} yes/"  "${config}"
	else
		echo "${auth} yes" | tee -a "${config}" > /dev/null
	fi

	systemctl restart ssh
}

main || exit 1
echo
echo "SUCCESS! SSH root login and password auth enabled."
echo

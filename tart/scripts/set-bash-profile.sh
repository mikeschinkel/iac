#!/usr/bin/env bash
set -eo pipefail

# Set this instead: /var/lib/cloud/data/set-hostname

PROFILE=".profile"
BASH_PROFILE=".bash_profile"

function set_bash_profile {
	local username="$1"
	local home_dir="/home/${username}"
	local profile="${home_dir}/${PROFILE}"
	local bash_profile="${home_dir}/${BASH_PROFILE}"
	local tmp_profile="${home_dir}/scripts/profile.sh"

	if [ -f "${bash_profile}" ]; then
		profile="${bash_profile}"
	fi
	touch "${profile}"

  # Make it easier to type
  {
  	cat "${profile}"
    echo
    echo 'alias k="kubectl"'
    echo 'alias kc="kubectl create "'
    echo 'alias ka="kubectl apply"'
    echo 'alias kd="kubectl delete"'
    echo 'alias sc="sudo systemctl "'
    echo 'alias jc="sudo journalctl "'
  	echo
  	echo cat /etc/hosts
  	echo
  } > "${tmp_profile}"

  mv "${tmp_profile}" "${bash_profile}"

  rm -rf "${profile}"

}
set_bash_profile "$@" || exit 1
echo
echo "SUCCESS! ${BASH_PROFILE} set to: $1."
echo

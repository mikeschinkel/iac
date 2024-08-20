#!/usr/bin/env bash
set -eo pipefail

configure_all() {
	vm_name="$1"
	username="$2"
	password="$3"
	packages="$4"

	export DEBIAN_FRONTEND=noninteractive

	# shellcheck disable=SC2086
	apt-get update \
		&& apt-get install -y ${packages} \
		&& apt-get upgrade -y \
		&& ./set-bash-profile.sh "${username}" \
		&& ./set-hostname.sh "${vm_name}" \
		&& ./install-yq.sh \
		&& ./install-avahi.sh \
		&& ./install-hosts-updater.sh "${username}" \
		&& ./install-samba.sh "${username}" "${password}" \
		&& ./install-docker.sh "${username}" \
		&& ./install-k3s.sh "${vm_name}" "${username}" \
		&& ./set-ssh-perms.sh \
		&& ./enable-root-ssh-login.sh

}

if ! configure_all "$@" ; then
	echo "Configure FAILED!"
	exit 1
fi

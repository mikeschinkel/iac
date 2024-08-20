#!/usr/bin/env bash
set -eo pipefail

BIN_DIR="/usr/local/bin"
HOSTS_CONST="hosts-const.sh"
# shellcheck disable=SC1090
source "./${HOSTS_CONST}"

SYSTEMD_DIR="${SYSTEMD_DIR:-}"
SCRIPT="${SCRIPT:-}"
SERVICE="${SERVICE:-}"
SCRIPT="${SCRIPT:-}"
NAME="${NAME:-}"

function install_hosts_updater {
	local username="$1"
	local home_dir="/home/${username}"

	cp "${home_dir}/scripts/${HOSTS_CONST}" "${BIN_DIR}/${HOSTS_CONST}"
	mv "${home_dir}/scripts/${SERVICE}" 		"${SYSTEMD_DIR}/"
	mv "${home_dir}/scripts/${SCRIPT}" 			"${BIN_DIR}/${SCRIPT}"

	systemctl daemon-reload
	systemctl enable "${NAME}"
}

install_hosts_updater "$@" || exit 1
echo
echo "SUCCESS! Host Updater installed."
echo


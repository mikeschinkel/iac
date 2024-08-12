#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source "${SCRIPT_DIR}/_shared.sh"

# Arguments
ESXI_USERNAME="${ESXI_USERNAME:-}"
ESXI_PASSWORD="${ESXI_PASSWORD:-}"
DISTRO_NAME="${DISTRO_NAME:-}"
DISTRO_VERSION="${DISTRO_VERSION:-}"

# Variables
EXTENSION="ovf"
VM_ROOT_DIR="/vmfs/volumes"
ESXI_HOST="${ESXI_HOST:-esxi.local}"
REMOTE_DATASTORE="${REMOTE_DATASTORE:-os}"
ESXI_ADDRESS="${ESXI_USERNAME}@${ESXI_HOST}"
OVF_NAME="${DISTRO_NAME}-${DISTRO_VERSION}"
OVF_PATH="${DISTRO_NAME}/${DISTRO_VERSION}"
OVF_FILENAME="${OVF_FILENAME:-${OVF_NAME}.${EXTENSION}}"
LOCAL_OVF_ROOT="${LOCAL_OVF_ROOT:-"$(host_get .host_output_dir)"}"
REMOTE_OVF_ROOT="${VM_ROOT_DIR}/${REMOTE_DATASTORE}/${EXTENSION}"
LOCAL_OVF_DIR="${LOCAL_OVF_ROOT}/${OVF_PATH}/${EXTENSION}"
REMOTE_OVF_DIR="${REMOTE_OVF_ROOT}/${OVF_NAME}"
REMOTE_DESTINATION="${ESXI_ADDRESS}:${REMOTE_OVF_DIR}/"

function check_vars {
	local fail=0
	if [ -z "${ESXI_USERNAME}" ]; then
		echo "ERROR: ESXI_USERNAME not set"
		fail=1
	fi
	if [ -z "${ESXI_USERNAME}" ]; then
		echo "ERROR: ESXI_PASSWORD not set"
		fail=1
	fi
	if [ -z "${DISTRO_NAME}" ]; then
		echo "ERROR: DISTRO_NAME not set"
		fail=1
	fi
	if [ -z "${DISTRO_VERSION}" ]; then
		echo "ERROR: DISTRO_VERSION not set"
		fail=1
	fi
	if [ $fail -eq 1 ] ; then
		echo "Required environment variables not set. Quitting." 2>&1
		exit 1
	fi
}

function upload_files {
	echo "Uploading from ${LOCAL_OVF_DIR}/* to ${REMOTE_DESTINATION}"
	sshpass -eESXI_PASSWORD scp "${LOCAL_OVF_DIR}/"* "${REMOTE_DESTINATION}"
}

function ensure_remote_dir {
	echo "Ensuring remote directory ${REMOTE_OVF_DIR}"
	# shellcheck disable=SC2029
	ssh "${ESXI_ADDRESS}" "mkdir -p '${REMOTE_OVF_DIR}'"
}

function main {
	check_vars

	# Ensure the directory this for OVF files
	if ! ensure_remote_dir ; then
			echo "ERROR: Failed to ensure remote directory '${REMOTE_OVF_ROOT}' on ESXI server." 2>&1
			exit 2
	fi

	# Upload files to ESXI server
	if ! upload_files ; then
			echo "ERROR: Failed to create upload ${REMOTE_OVF_DIR}/* to ESXI server." 2>&1
			exit 3
	fi

	echo "SUCCESS: Files at ${REMOTE_OVF_DIR}/* uploaded."
}

main
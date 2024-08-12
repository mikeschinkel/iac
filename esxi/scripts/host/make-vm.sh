#!/bin/bash

# Variables
ESXI_HOST="${ESXI_HOST:-esxi.local}"
REMOTE_DATASTORE="${REMOTE_DATASTORE:-ds}"
ESXI_USERNAME="${ESXI_USERNAME:}"
ESXI_PASSWORD="${ESXI_PASSWORD:}"
OVF_NAME="${OVF_NAME:-}"
VM_NAME="${VM_NAME:-}"
LOCAL_OVF_DIR="${LOCAL_OVF_DIR:-}"
function check_vars {
	local fail=0
	if [ -n "${ESXI_USERNAME}" ]; then
		echo "ERROR: ESXI_USERNAME not set"
		fail=1
	fi
	if [ -n "${ESXI_USERNAME}" ]; then
		echo "ERROR: ESXI_PASSWORD not set"
		fail=1
	fi
	if [ -n "${OVF_NAME}" ]; then
		echo "ERROR: OVF_NAME not set"
		fail=1
	fi
	if [ -n "${VM_NAME}" ]; then
		echo "ERROR: VM_NAME not set"
		fail=1
	fi
	if [ $fail -eq 1 ] ; then
		echo "Required environment variables not set. Quitting."
	}
}


# Create the target directory on ESXi
sshpass -p "${ESXI_PASSWORD}" ssh ${ESXI_USERNAME}@${ESXI_HOST} "mkdir -p /vmfs/volumes/${REMOTE_DATASTORE}/${VM_NAME}"

# Upload OVF and VMDK files to the ESXi datastore
sshpass -p "${ESXI_PASSWORD}" scp ${LOCAL_OVF_DIR}/* ${ESXI_USERNAME}@${ESXI_HOST}:/vmfs/volumes/${REMOTE_DATASTORE}/${VM_NAME}/

# Register the VM on ESXi
sshpass -p "${ESXI_PASSWORD}" ssh ${ESXI_USERNAME}@${ESXI_HOST} "vim-cmd solo/registervm /vmfs/volumes/${REMOTE_DATASTORE}/${VM_NAME}/${VM_NAME}.ovf"

# List all VMs to get the VMID
sshpass -p "${ESXI_PASSWORD}" ssh ${ESXI_USERNAME}@${ESXI_HOST} "vim-cmd vmsvc/getallvms"

# Power on the VM (replace <VMID> with the actual ID from the previous command)
# sshpass -p "${ESXI_PASSWORD}" ssh ${ESXI_USERNAME}@${ESXI_HOST} "vim-cmd vmsvc/power.on <VMID>"

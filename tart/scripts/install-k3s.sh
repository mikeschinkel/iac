#!/usr/bin/env bash
set -eo pipefail

export DEBIAN_FRONTEND=noninteractive

K3S_YAML="/etc/rancher/k3s/k3s.yaml"
K3S_VERSION="v1.30.3+k3s1"

function log_error {
	local message="$1"
	echo "ERROR: ${message}" >&2
}
function log_warning {
	local message="$1"
	echo "WARNING: ${message}" >&2
}

function install_k3s {
	local vm_name="$1"
	local node="${vm_name}.local"

	# Check last character of $vm_name to see if it is not 1, e.g. not `k1`
	if [ "${vm_name:$(( ${#vm_name}-1 ))}" != "1" ] ; then
		echo "Not the control plane, skipping K3S install."
		return 2
	fi

  # Install k3s
  # See https://youtu.be/O3s3YoPesKs?t=120
  # See https://github.com/k3s-io/k3s/issues/10578#issuecomment-2257526988
  if ! curl -sfL https://get.k3s.io \
  	| INSTALL_K3S_VERSION="${K3S_VERSION}" \
  	  K3S_KUBECONFIG_MODE=777 sh -s - \
				server --tls-san "${node}"; then
					error_log "Failed to install K3s control plane master: ${node}."
					return 1
	fi

  # Given permissions to k3s.yaml
  # See: https://blog.mphomphego.co.za/blog/2021/04/19/note-to-self-error-loading-config-file-k3s.yaml.html
  if ! chmod 644 ${K3S_YAML}; then
		error_log "Failed to chmod ${K3S_YAML} to 644."
		return 1
	fi

  if ! kubectl get nodes; then
  	log_error "Failed to get K3s nodes; did install not work correctly?"
		return 1
	fi

}
install_k3s "$@" || echo
case "$?" in
	0)
		echo
		echo "SUCCESS! k3s installed."
		echo
		;;
	1)
		exit 1
		;;
	*)
		#	Do nothing, ignore
		;;
esac


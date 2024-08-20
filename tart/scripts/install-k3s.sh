#!/usr/bin/env bash
set -eo pipefail

export DEBIAN_FRONTEND=noninteractive

function install_k3s {
	local vm_name="$1"

	# Check last character of $vm_name to see if it is not 1, e.g. not `k1`
	if [ "${vm_name:$(( ${#vm_name}-1 ))}" != "1" ] ; then
		echo "Not the control plane, skipping K3S install."
		return 0
	fi

  # Install k3s
  # See https://youtu.be/O3s3YoPesKs?t=120
  # See https://github.com/k3s-io/k3s/issues/10578#issuecomment-2257526988
  curl -sfL https://get.k3s.io \
  	| INSTALL_K3S_VERSION=v1.30.3+k3s1 K3S_KUBECONFIG_MODE=777 sh -

  # Given permissions to k3s.yaml
  # See: https://blog.mphomphego.co.za/blog/2021/04/19/note-to-self-error-loading-config-file-k3s.yaml.html
  chmod 644 /etc/rancher/k3s/k3s.yaml

  kubectl get nodes

}
install_k3s "$@" || exit 1
echo
echo "SUCCESS! k3s installed."
echo

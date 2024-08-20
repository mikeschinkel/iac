#!/usr/bin/env bash
set -eo pipefail

export DEBIAN_FRONTEND=noninteractive

function find_profile {
	local profile="${HOME}/.bash_profile"
	if [ -f "${profile}" ] ; then
		echo "${profile}"
	fi
	echo "${HOME}/.profile"
}

function install_k3s {
	local profile
	local kaliases="/tmp/set-kaliases.sh"
	local temprofile="/tmp/profile"

  # Install k3s
  # See https://youtu.be/O3s3YoPesKs?t=120
  # See https://github.com/k3s-io/k3s/issues/10578#issuecomment-2257526988
  curl -sfL https://get.k3s.io \
  	| INSTALL_K3S_VERSION=v1.30.3+k3s1 K3S_KUBECONFIG_MODE=777 sh -

  # Given permissions to k3s.yaml
  # See: https://blog.mphomphego.co.za/blog/2021/04/19/note-to-self-error-loading-config-file-k3s.yaml.html
  chmod 644 /etc/rancher/k3s/k3s.yaml

  # Make it easier to type
  {
    echo
    echo 'alias k="kubectl"'
    echo 'alias kc="kubectl create "'
    echo 'alias ka="kubectl apply"'
    echo 'alias kd="kubectl delete"'
  } > "${kaliases}"

	profile="$(find_profile)"
	touch "${profile}"
  cat "${profile}" "${kaliases}" | tee ${temprofile} > /dev/null
  sudo mv ${temprofile} "${profile}"

  kubectl get nodes

}
install_k3s || exit 1
echo
echo "SUCCESS! k3s installed."
echo

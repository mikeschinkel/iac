#!/usr/bin/env bash

function install_k3s {
	local profile="${HOME}/.bash_profile"
	local kaliases="/tmp/kaliases.sh"
	local temprofile="/tmp/.bash_profile"

  # Install k3s
  # See https://youtu.be/O3s3YoPesKs?t=120
  curl -sfL https://get.k3s.io | sh -

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

  cat "${profile}" "${kaliases}" | sudo tee ${temprofile} > /dev/null
  sudo mv ${temprofile} "${profile}"

  kubectl get nodes

}
install_k3s
echo
echo "SUCCESS! k3s installed."
echo
echo "NOTE! Run 'source /tmp/kaliases' to be able to use aliases immediately."
echo

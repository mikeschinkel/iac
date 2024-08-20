#!/usr/bin/env bash
set -eo pipefail

export DEBIAN_FRONTEND=noninteractive

# See https://phoenixnap.com/kb/docker-permission-denied

function _install_docker {
	local username="$1"
  local to_install="$2"
  local to_remove="$3"
  local distro
  local codename

  # Install prerequisites
  apt-get update
  # shellcheck disable=SC2086
  apt-get install --yes ${to_install} \
    ca-certificates \
    curl \
    gnupg
  # Upgrade, just to be sure
  apt-get upgrade -y

  # Use /etc/os-release to determine the distribution
  distro=$(grep "^ID=" /etc/os-release | awk -F= '{print $2}')

  # Add Docker’s official GPG key
  curl -fsSL "https://download.docker.com/linux/${distro}/gpg" \
    | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

	# Set up the Docker repository
  codename=$(grep "^VERSION_CODENAME=" /etc/os-release | awk -F= '{print $2}')

  printf \
    "deb [arch=%s signed-by=%s] %s %s stable\n" \
    "$(dpkg --print-architecture)" \
    "/usr/share/keyrings/docker-archive-keyring.gpg" \
    "https://download.docker.com/linux/${distro}" \
    "${codename}" \
      | tee /etc/apt/sources.list.d/docker.list > /dev/null

  # Install Docker
  apt-get update && \
  apt-get install --yes \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-compose-plugin && \
	apt-get upgrade --yes

  # Remove any unnecessary packages (for Ubuntu)
  if [ -n "${to_remove}" ] ; then
    # shellcheck disable=SC2086
    apt-get remove --yes ${to_remove}
  fi

  # Verify Docker installation
  docker version
  systemctl enable docker
  systemctl start docker
  systemctl status docker
  usermod -aG docker "${username}"

}
function install_docker_debian {
	local username="$1"
  local to_install="apt-transport-https"
  local to_remove=""

echo "STEP: AD1"
  _install_docker "${username}" "${to_install}" "${to_remove}"
}
function install_docker_ubuntu {
	local username="$1"
  local to_install=""
  local to_remove="bridge-utils dns-root-data dnsmasq-base ubuntu-fan"

echo "STEP: AU1"
  _install_docker "${username}" "${to_install}" "${to_remove}"
}

# Determine the distribution and call the appropriate function
if grep -q "Debian" /etc/os-release; then
	  install_docker_debian "$@" || exit 1
elif grep -q "Ubuntu" /etc/os-release; then
	  install_docker_ubuntu "$@" || exit 1
else
  echo "Unsupported distribution: $(cat /etc/os-release)"
  exit 1
fi
echo
echo "SUCCESS! Docker installed for user: $1."
echo

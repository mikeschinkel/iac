#!/usr/bin/env bash
set -eo pipefail

# See https://phoenixnap.com/kb/docker-permission-denied

DOCKER_USER=mikeschinkel

function install_docker_debian {
  _install_docker "apt-transport-https" ""
}
function install_docker_ubuntu {
  _install_docker "" "bridge-utils dns-root-data dnsmasq-base ubuntu-fan"
}
function _install_docker {
  local to_install="$1"
  local to_remove="$2"
  local distro
  local codename

  # Install prerequisites
  ${SUDO} apt-get update
  # shellcheck disable=SC2086
  ${SUDO} apt-get install --yes ${to_install} \
    ca-certificates \
    curl \
    gnupg

  # Use /etc/os-release to determine the distribution
  distro=$(grep "^ID=" /etc/os-release | awk -F= '{print $2}')

  # Add Docker’s official GPG key
  curl -fsSL "https://download.docker.com/linux/${distro}/gpg" \
    | ${SUDO} gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Set up the Docker repository
  codename=$(grep "^VERSION_CODENAME=" /etc/os-release | awk -F= '{print $2}')
  printf \
    "deb [arch=%s signed-by=%s] %s %s stable\n" \
    "$(dpkg --print-architecture)" \
    "/usr/share/keyrings/docker-archive-keyring.gpg" \
    "https://download.docker.com/linux/${distro}" \
    "${codename}" \
      | ${SUDO} tee /etc/apt/sources.list.d/docker.list > /dev/null

  # Install Docker
  ${SUDO} apt-get update
  ${SUDO} apt-get install --yes \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-compose-plugin

  # Remove any unnecessary packages (for Ubuntu)
  if [ -n "${to_remove}" ] ; then
    # shellcheck disable=SC2086
    ${SUDO} apt-get remove --yes ${to_remove}
  fi

  # Verify Docker installation
  ${SUDO} docker version
  ${SUDO} systemctl enable docker
  ${SUDO} systemctl start docker
  ${SUDO} systemctl status docker

  ${SUDO} usermod -aG docker "${DOCKER_USER}"

  # Note: `newgrp docker` is not ideal for scripts, but okay for provisioning
  # See: https://unix.stackexchange.com/a/18902/144192
  ${SUDO} newgrp docker

  ${SUDO} docker run hello-world
}

# Determine the distribution and call the appropriate function
if grep -q "Debian" /etc/os-release; then
  install_docker_debian
elif grep -q "Ubuntu" /etc/os-release; then
  install_docker_ubuntu
else
  echo "Unsupported distribution"
  exit 1
fi

#!/usr/bin/env bash
set -eo pipefail

export DEBIAN_FRONTEND=noninteractive

AVAHI_CONFIG="/etc/avahi/avahi-daemon.conf"

function install_avahi {

  apt-get update \
    && apt-get install --yes \
    	avahi-daemon \
    	avahi-utils \
    && \
    apt-get upgrade --yes \
    	avahi-daemon \
    	avahi-utils

  if_name="$(ip --json addr show | jq -r '.[]|select(.link_type=="ether")|.ifname'|head -n 1)"

  sed -i -E "s/(use-ipv6)=yes/\1=no/" "${AVAHI_CONFIG}"
  sed -i -E "s/(publish-workstationz)=no/\1=yes/"  "${AVAHI_CONFIG}"
  sed -i -E "s/#(allow-interfaces)=eth0/\1=${if_name}/"  "${AVAHI_CONFIG}"

	systemctl restart avahi-daemon \
  	&& systemctl status avahi-daemon

}

install_avahi "$@" || exit 1
echo
echo "SUCCESS! Avahi installed."
echo


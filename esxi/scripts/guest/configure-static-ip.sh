


function get_if_name {
  local query='.[]|select(.link_type=="ether") | .ifname'

  ip -json addr show \
    | jq -r "${query}"
}

function configure_static_ip {

  if_name="$(get_if_name)"

  sed -i "s/iface ${if_name} inet dhcp/auto ${if_name}\niface ${if_name} inet static/" \
    /etc/network/interfaces

  { ens192
    echo "address 192.168.1.110"
    echo "netmask 255.255.255.0"
    echo "gateway 192.168.1.1"
    echo "dns-nameservers 8.8.8.8 8.8.4.4"
  } >> /etc/network/interfaces
  systemctl restart networking
  ip -c addr show "${if_name}" | grep "${if_name}"

}






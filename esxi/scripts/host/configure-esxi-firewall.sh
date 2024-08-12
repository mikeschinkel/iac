#!/bin/bash

ESXI_HOST="${ESXI_HOST:-esxi.local}"

function esxi_firewall() {
  local status="$1"

  # (Dis|En)able firewall
  sshpass -p "${ESXI_PASSWORD}" ssh \
    -o StrictHostKeyChecking=no \
    "${ESXI_USERNAME}"@"${ESXI_HOST}" \
    "esxcli network firewall set --enabled ${status}"
  echo "Firewall for http://${ESXI_HOST} ${ESXI_FIREWALL_ACTION}d"
}
case "${ESXI_FIREWALL_ACTION}" in
    disable)
        esxi_firewall "false"
        ;;
    enable)
        esxi_firewall "true"
        ;;
    *)
        echo "ERROR Invalid value for \$ESXI_FIREWALL_ACTION: $1; expected either 'enable' or 'disable'"
        ;;
esac

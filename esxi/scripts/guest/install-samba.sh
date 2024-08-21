#!/usr/bin/env bash

function get_fruit_config {
	cat <<- EOF
	fruit:metadata = stream
	fruit:model = RackMac
	fruit:posix_rename = yes
	fruit:veto_appledouble = no
	fruit:wipe_intentionally_left_blank_rfork = yes
	fruit:delete_empty_adfiles = yes
	vfs objects = catia fruit streams_xattr
	min protocol = SMB2
	EOF
}

function install_samba {
  local password="$1"

  if [ -z "${password}" ] ; then
    echo "Password:"
    read -r -s password
	fi

  apt-get update \
    && apt-get install --yes \
      samba \
      samba-client \
      samba-common \
    && \
    apt-get upgrade --yes \
      samba \
      samba-client \
      samba-common

  if_name="$(ip --json addr show | jq -r '.[]|select(.link_type=="ether")|.ifname'|head -n 1)"

  sed -i -E 's/;\s*(bind interfaces only = yes)/\1/' /etc/samba/smb.conf
  sed -i -E "s/;\s*((interfaces =).+$)/\2 ${if_name}/" /etc/samba/smb.conf
  sed -i -E "/\[global\]/a security = user\nbrowseable = yes" /etc/samba/smb.conf
  sed -i -E 's/(mask =) 0700/\1 0755/' /etc/samba/smb.conf
  sed -i -E "0,/\s*read only = yes/s//read only = no\nwritable = yes/" /etc/samba/smb.conf

	if ! grep -q 'fruit:metadata = stream' /etc/samba/smb.conf; then
		while IFS= read -r line; do
				echo "$line" >> /tmp/etc_samba_smb.conf
				if [[ "$line" == "browseable = yes" ]]; then
						get_fruit_config >> /tmp/etc_samba_smb.conf
				fi
		done < /etc/samba/smb.conf && mv /tmp/etc_samba_smb.conf /etc/samba/smb.conf
	fi

  (echo "${password}"; echo "${password}") | smbpasswd -s -a mikeschinkel

  sudo systemctl enable smbd.service \
    && sudo systemctl enable nmbd.service

  sudo systemctl restart smbd.service \
    && sudo systemctl restart nmbd.service \
    && sudo systemctl restart avahi-daemon

  sudo systemctl status smbd.service \
    && sudo systemctl status nmbd.service

}

# $1 = password to set
install_samba ""
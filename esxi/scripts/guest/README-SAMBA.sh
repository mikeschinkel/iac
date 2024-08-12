#!/usr/bin/env bash
# https://programmer.group/samba-configuration-shared-user-home-directory.html
# https://unix.stackexchange.com/questions/36853/how-do-i-define-a-samba-share-so-that-every-user-can-only-see-its-own-home
# https://www.freedesktop.org/software/systemd/man/systemd.net-naming-scheme.html
# http://zeroconf.org/
# https://wiki.debian.org/Avahi
# https://unix.stackexchange.com/questions/680371/debian-11-failed-to-resolve-local-names
# https://unix.stackexchange.com/questions/134483/why-is-my-ethernet-interface-called-enp0s10-instead-of-eth0
# https://github.com/systemd/systemd/blob/ccddd104fc95e0e769142af6e1fe1edec5be70a6/src/udev/udev-builtin-net_id.c#L29

function get_fruit_config {
  cat <<- EOF > foo.txt
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

  apt-get update \
    && apt-get install --yes \
      samba \
      samba-client \
      samba-common \
    && apt-get upgrade --yes \
      samba \
      samba-client \
      samba-common

  if_name="$(ip --json addr show | jq -r '.[]|select(.link_type=="ether")|.ifname'|head -n 1)"

  sed -i -E 's/;\s*(bind interfaces only = yes)/\1/' /etc/samba/smb.conf
  sed -i -E 's/;\s*((mask =) 0700/\1 0755/' /etc/samba/smb.conf
  sed -i -E "s/;\s*((interfaces =).+$)/\2 ${if_name}/" < /etc/samba/smb.conf
  sed -i -E "/\[global\]/a security = user\nbrowseable = yes" < /etc/samba/smb.conf
  sed -i -E 's/;\s*((read only =) yes/\1 no\nwritable = yes\n$(get_fruit_config)/' /etc/samba/smb.conf



  # /etc/samba/smb.conf
  # interfaces = enp2s0
  # bind interfaces only = yes
  # browseable = yes

  smbpasswd -a mikeschinkel

  systemctl enable smbd.service
  systemctl enable nmbd.service
  systemctl restart smbd.service
  systemctl restart nmbd.service
  systemctl status smbd.service
  systemctl status nmbd.service

#  mkdir -p /opt/samba/everyone
#  groupadd everyone
#  chgrp everyone /opt/samba/everyone
#  chmod -R 770 /opt/samba/everyone
#  usermod -a -G everyone mikeschinkel
  smbpasswd -a mikeschinkel

}

#https://www.samba.org/samba/docs/current/man-html/smb.conf.5.html

[global]
netbios name = NETBIOS_NAME_GOES_HERE
security = user
dns proxy = no
[homes]
comment = Home Directories
browsable = yes
read only = no
writable = yes
valid users = <username> @<groupname> %S

#https://superuser.com/a/1541328/46038
#https://www.samba.org/samba/docs/current/man-html/vfs_fruit.8.html

[homes]
comment = Home Directories
browseable = yes
read only = no
writable = yes
create mask = 0775
directory mask = 0775
valid users = %S


https://phoikoi.io/2018/05/15/samba-avahi-bonjour-mac-visible.html

https://superuser.com/a/349699/46038

sudo defaults write /Library/Preferences/com.apple.AppleFileServer guestAccess -bool YES \
  && sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.smb.server AllowGuestAccess -bool YES \
  && sudo defaults write /Library/Preferences/com.apple.AppleFileServer guestAccess -bool NO \
  && sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.smb.server AllowGuestAccess -bool NO
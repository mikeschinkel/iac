#!/usr/bin/env bash

SUDO="$(which sudo)"

function maybe_chmod {
  local perms="$1"
  local path="$2"
  if [ "$(stat -c '%a' "${path}")" == "${perms}" ] ; then
    return
  fi
  printf "Before: %s\n" "$(stat -c '%a %n' "${path}")"
  ${SUDO} chmod "${perms}" "${path}"
  printf "After: %s\n" "$(stat -c '%a' "${path}")"
}

maybe_chmod 700 .ssh

for file in .ssh/*; do
  if [[ "${file}" =~ \.pub$ ]]; then
    # For Public keys
    maybe_chmod 644 "${file}"
  else
    # For Private keys, config and authorized_keys
    maybe_chmod 600 "${file}"
  fi
done


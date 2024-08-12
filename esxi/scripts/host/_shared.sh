#!/usr/bin/env bash

function json_get {
	local file="$1"
	local path="$2"
	jq -r "${path}" "${SCRIPT_DIR}/../../json/${file}"
}
function host_get {
	local path="$1"
	json_get host.json "${path}"
}


#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# Author: Martin Røed Jacobsen
# Written with Debian 8 in mind.
# -----------------------------------------------------------------------------

cfg_firewall_zone="trusted"
cfg_hostnames=(
	"example.com"
	"another.example.org"
	"some-host.on-isp.com"
)

# Internal functions and variables.
# -----------------------------------------------------------------------------

function fw_allow_ip {
	firewall-cmd \
		--zone=${cfg_firewall_zone} \
		--add-source=${1} >/dev/null 2>&1
}

function fw_reload {
	firewall-cmd \
		--reload >/dev/null 2>&1;
}

# Main script logic.
# -----------------------------------------------------------------------------

# Clear all existing non-permanent firewall rules.
fw_reload

# Process all configured hostnames.
if [ ${#cfg_hostnames[@]} -gt 0 ]; then
	for hostname in "${cfg_hostnames[@]}"; do
		ip_addresses=$(dig "${hostname}" A "${hostname}" AAAA +short)
		for ip_address in ${ip_addresses}; do
			printf "allow %-39s %s\n" \
				"${ip_address}" \
				"${hostname}"
			fw_allow "${ip_address}"
		done
	done
fi

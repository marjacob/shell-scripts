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

function fw_allow_ipv4 {
	firewall-cmd \
		--zone=${cfg_firewall_zone} \
		--add-source=${1}/32 >/dev/null 2>&1
}

function fw_allow_ipv6 {
	firewall-cmd \
		--zone=${cfg_firewall_zone} \
		--add-source=${1}/64 >/dev/null 2>&1
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
		# Allow each IPv4 address pointed to by the hostname.
		ipv4_address_list=$(dig "${hostname}" A +short)
		for ipv4_address in ${ipv4_address_list}; do
			printf "allow %-39s %s\n" \
				"${ipv4_address}" \
				"${hostname}"
			fw_allow_ipv4 "${ipv4_address}"
		done

		# Allow each IPv6 address pointed to by the hostname.
		ipv6_address_list=$(dig "${hostname}" AAAA +short)
		for ipv6_address in ${ipv6_address_list}; do
			printf "allow %-39s %s\n" \
				"${ipv6_address}" \
				"${hostname}"
			fw_allow_ipv6 "${ipv6_address}"
		done
	done
fi

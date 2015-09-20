#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# Written with Debian 8 in mind.

conf_hostname="shion"
conf_timezone="Europe/Oslo"
conf_users="martin;terje"
conf_sudoers="martin"
conf_packages="
	build-essential
	gdb
	git
	htop
	mosh
	sudo
	tmux
	tree
	ufw
	valgrind
	vim
	vlock
"

# Suppress requests for information during package configuration.
export DEBIAN_FRONTEND=noninteractive

# Determines whether a program is available or not.
function has {
	command -v "$@" >/dev/null 2>&1	
}


# Make sure that the user is actually root.
# ----------------------------------------------------------------------

if [[ ${EUID} -ne 0 ]]; then
	bold=$(tput bold)
	cyan=$(tput setaf 6)
	normal=$(tput sgr0)
	red=$(tput setaf 1)

	printf ""`
		`"${red}${bold}error: "`
		`"${normal}must be run as ${bold}root${normal} "`
		`"${cyan}[you are $(whoami)]${normal}\n"

	exit 1;
fi

# Configure the system hostname.
# ----------------------------------------------------------------------
# The hostnamectl command is a part of systemd.

if has hostnamectl; then
	hostnamectl set-hostname "$conf_hostname"
else
	echo "${conf_hostname}" > /etc/hostname
	hostname -F /etc/hostname
fi

# Configure the system time zone.
# ----------------------------------------------------------------------

echo "$conf_timezone" > /etc/timezone
dpkg-reconfigure -f noninteractive tzdata

# Update the system and install new packages.
# ----------------------------------------------------------------------

aptitude update
aptitude upgrade -y
aptitude -y install ${conf_packages}

# Configure and enable the firewall.
# ----------------------------------------------------------------------

ufw default deny incoming
ufw default allow outgoing
ufw limit 60001/udp
ufw limit ssh/tcp
ufw --force enable

# Create and configure user accounts.
# ----------------------------------------------------------------------
# See http://stackoverflow.com/a/918931 for an explanation of IFS.

IFS=';' read -ra ADDR <<< "${conf_users}"
for user in "${ADDR[@]}"; do
	# Create user account.
	adduser --disabled-password --gecos "" "${user}"

	# Create SSH configuration directory.
	user_ssh_home="$(eval echo ~${user})/.ssh"
	mkdir -p "${user_ssh_home}"
	
	# Generate SSH key pair.
	ssh-keygen -q -N "" -t rsa -b 4096 \
		-C "${user}@${conf_hostname}" \
		-f "${user_ssh_home}/id_rsa"

	# Create default SSH configuration files.
	cp ${user_ssh_home}/id_rsa.pub ${user_ssh_home}/authorized_keys
	touch ${user_ssh_home}/{config,known_hosts}

	# Set the correct permissions.
	chown -R ${user}:${user} ${user_ssh_home}
	chmod 700 ${user_ssh_home}
	chmod 600 ${user_ssh_home}/*
done

# Grant sudo permissions to specified users.
IFS=';' read -ra ADDR <<< "${conf_sudoers}"
for user in "${ADDR[@]}"; do
	usermod -a -G sudo "${user}"
done

exit 0

# Further reading.
# ----------------------------------------------------------------------
# - The unofficial Bash Strict Mode: 
#   http://redsymbol.net/articles/unofficial-bash-strict-mode/

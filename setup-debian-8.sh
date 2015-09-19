#!/usr/bin/env bash

# Written with Debian 8 in mind.

conf_hostname="shion"
conf_timezone="Europe/Oslo"
conf_users="martin;terje"
conf_sudoers="martin"
conf_packages=" \
	build-essential \
	gdb \
	git \
	mosh \
	sudo \
	tmux \
	tree \
	ufw \
	valgrind \
	vim \
	vlock \
"

# Suppress requests for information during package configuration.
export DEBIAN_FRONTENT=noninteractive

# Determines whether a program is available or not.
function has {
	command -v "$@" >/dev/null 2>&1	
}

# Make sure that the user is actually root.
if [[ ${EUID} -ne 0 ]]; then
	printf "error: must be run as root\n"
	exit 1;
fi

# Configure the system hostname.
# -----------------------------------------------------------------------------

if has hostnamectl; then
	hostnamectl set-hostname "$conf_hostname"
else
	echo "${conf_hostname}" > /etc/hostname
	hostname -F /etc/hostname
fi

# Configure the system time zone.
# -----------------------------------------------------------------------------

echo "$conf_timezone" > /etc/timezone
dpkg-reconfigure -f noninteractive tzdata

# Update the system and install new packages.
# -----------------------------------------------------------------------------

aptitude update
aptitude upgrade -y
aptitude -y install ${conf_packages}

# Configure and enable the firewall.
# -----------------------------------------------------------------------------

ufw default deny incoming
ufw default allow outgoing
ufw limit 60001/udp
ufw limit ssh/tcp
ufw --force enable

# Create and configure user accounts.
# -----------------------------------------------------------------------------

function ssh_keygen {
	user="$1"
	hostmask="${user}@${conf_hostname}"
	sudo -u "${user}" -s << EOF
		mkdir -p "${HOME}/.ssh"
		ssh-keygen -q -N "" -t rsa -b 4096 \
			-C "${hostmask}" \
			-f "${HOME}/.ssh/id_rsa"
		cp "${HOME}/.ssh/id_rsa.pub" "${HOME}/.ssh/authorized_keys"
		touch "${HOME}/.ssh/{config,known_hosts}"
		chown -R "${user}:${user}" "${HOME}/.ssh"
		chmod 700 "${HOME}/.ssh"
		chmod 600 "${HOME}/.ssh/*"
EOF
}

# Create users.
IFS=';' read -ra ADDR <<< "${conf_users}"
for user in "${ADDR[@]}"; do
	adduser --disabled-password --gecos "" "${user}"
	ssh_keygen "${user}"
done

# Grant sudo permissions to specified users.
IFS=';' read -ra ADDR <<< "${conf_sudoers}"
for user in "${ADDR[@]}"; do
	usermod -a -G sudo "${user}"
done


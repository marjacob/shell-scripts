#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# Written with Debian 8 in mind.
# ----------------------------------------------------------------------

conf_hostname="shion"

conf_timezone="Europe/Oslo"

# Configure normal user accounts.
conf_users=(
	"martin"
	"terje"
)

# Users that should be granted root access.
conf_sudoers=(
	"martin"
)

# Automatically installed packages.
conf_packages=(
	"apt-transport-https"
	"build-essential"
	"checkinstall"
	"cmake"
	"curl"
	"gdb"
	"git"
	"git-doc"
	"htop"
	"libcurl4-doc"
	"libcurl4-gnutls-dev"
	"libicu-dev"          # ZNC dependency (optional).
	"libperl-dev"         # ZNC dependency.
	"libssl-dev"          # ZNC dependency.
	"pkg-config"          # ZNC dependency.
	"stow"
	"strace"
	"sudo"
	"tmux"
	"tree"
	"ufw"
	"valgrind"
	"vim"
	"vlock"
)

# Define functions and variables.
# ----------------------------------------------------------------------

# Suppress requests for information during package configuration.
# http://serverfault.com/a/227194
export DEBIAN_FRONTEND=noninteractive

# The codename of the current Debian version.
# http://unix.stackexchange.com/a/180779
debian_codename=$(awk -F"[)(]+" '/VERSION=/ {print $2}' /etc/os-release)

# Determines whether a program is available or not.
function has {
	command -v "$@" >/dev/null 2>&1	
}

# Downloads and installs signing keys for apt.
function apt_key_add {
	wget -qO - "${1}" | apt-key add -
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
	hostnamectl set-hostname "${conf_hostname}"
else
	echo "${conf_hostname}" > /etc/hostname
	hostname -F /etc/hostname
fi

# Configure the system time zone.
# ----------------------------------------------------------------------

echo "${conf_timezone}" > /etc/timezone
dpkg-reconfigure -f noninteractive tzdata

# Install third-party signing keys.
# ----------------------------------------------------------------------

# nginx
apt_key_add "http://nginx.org/keys/nginx_signing.key"

# WeeChat
apt-key adv \
	--keyserver keys.gnupg.net \
	--recv-keys 11E9DE8848F2B65222AA75B8D1820DB22A11534E

# Configure additional repositories.
# ---------------------------------------------------------------------

# nginx
printf ""`
	`"deb http://nginx.org/packages/mainline/debian/ "`
		`"${debian_codename} nginx\n"`
	`"deb-src http://nginx.org/packages/mainline/debian/ "`
		`"${debian_codename} nginx\n" \
	> /etc/apt/sources.list.d/nginx.list

# WeeChat
printf ""`
	`"deb http://weechat.org/debian ${debian_codename} main\n" \
	> /etc/apt/sources.list.d/nginx.list

# Update the system and install new packages.
# ----------------------------------------------------------------------

aptitude update
aptitude upgrade -y
aptitude -y install ${conf_packages[@]}

# Configure and enable the firewall.
# ----------------------------------------------------------------------

ufw default deny incoming
ufw default allow outgoing
ufw limit ssh/tcp
ufw --force enable

# Create and configure user accounts.
# ----------------------------------------------------------------------

# Create user accounts and SSH key pairs.
for user in "${conf_users[@]}"; do
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
	chmod -R 600 ${user_ssh_home}
	chmod 700 ${user_ssh_home}
done

# Grant sudo permissions to specified users.
for user in "${conf_sudoers[@]}"; do
	usermod -a -G sudo "${user}"
done

exit 0

# Further reading.
# ----------------------------------------------------------------------
# - Terminal Colors With 'tput':
#   http://www.tldp.org/HOWTO/Bash-Prompt-HOWTO/x405.html
# - The Unofficial Bash Strict Mode: 
#   http://redsymbol.net/articles/unofficial-bash-strict-mode
# - The Internal Field Separator (IFS):
#   http://stackoverflow.com/a/918931

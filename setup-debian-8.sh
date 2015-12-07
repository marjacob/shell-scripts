#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# Author: Martin Røed Jacobsen
# Written with Debian 8 in mind.
# -----------------------------------------------------------------------------

conf_hostname="ion"
conf_timezone="Europe/Oslo"

# Configure regular user accounts.
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
	"autossh"
	"build-essential"
	"checkinstall"
	"cmake"
	"curl"
	"firewalld"
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
	"valgrind"
	"vim"
	"vlock"
	"xauth"	              # Allows X11 forwarding.
)

# Internal functions and variables.
# -----------------------------------------------------------------------------

# Suppress requests for information during package configuration.
# http://serverfault.com/a/227194
export DEBIAN_FRONTEND=noninteractive

# Color escape codes.
bold=$(tput bold)
cyan=$(tput setaf 6)
green=$(tput setaf 2)
normal=$(tput sgr0)
red=$(tput setaf 1)

# Determines whether a program is available or not.
function has {
	command -v "${@}" >/dev/null 2>&1
}

# Updates the package list.
function apt_update {
	printf "${bold}Updating package list...${normal}\n"
	aptitude update
}

# Upgrades installed packages.
function apt_upgrade {
	printf "${bold}Upgrading installed packages...${normal}\n"
	aptitude upgrade -y
}

# Installs new packages.
function apt_install {
	printf "${bold}Installing new packages...${normal}\n"
	aptitude -y install "${@}"
}

# Installs new signing keys.
function apt_add_key {
	printf "${bold}Installing ${2} signing key... "

	apt-key adv \
		--keyserver "keys.gnupg.net" \
		--recv-keys "${1}" >/dev/null 2>&1

	local rc=${?}

	if [ ${rc} -eq 0 ]; then
		printf "${green}OK${normal}\n"
	else
		printf "${red}FAILED${normal}\n"
	fi

	return ${rc}
}

# Make sure that the user is actually root.
# -----------------------------------------------------------------------------

if [[ ${EUID} -ne 0 ]]; then
	printf ""`
		`"${red}${bold}error: "`
		`"${normal}must be run as ${bold}root${normal} "`
		`"${cyan}[you are $(whoami)]${normal}\n"

	exit 1;
fi

# Configure the system hostname.
# -----------------------------------------------------------------------------
# The hostnamectl command is a part of systemd.

printf "${bold}Setting hostname to \"${conf_hostname}\"...${normal}\n"

if has hostnamectl; then
	hostnamectl set-hostname "${conf_hostname}"
else
	echo "${conf_hostname}" > /etc/hostname
	hostname -F /etc/hostname
fi

# Configure the system time zone.
# -----------------------------------------------------------------------------

printf "${bold}Setting timezone to \"${conf_timezone}\"... "

echo "${conf_timezone}" > "/etc/timezone"
if dpkg-reconfigure -f noninteractive tzdata >/dev/null 2>&1; then
	printf "${green}OK${normal} [%s]\n" "$(date)"
else
	printf "${red}FAILED${normal}\n"
fi

# Install prerequisite packages.
# -----------------------------------------------------------------------------

required_packages=(
	"apt-transport-https"
	"lsb-release"
	"pwgen"
)

if [ ${required_packages} ]; then
	apt_update
	apt_upgrade
	apt_install "${required_packages[@]}"
fi

# Find the codename of the current Linux distribution.
# -----------------------------------------------------------------------------

lsb_codename=$(lsb_release -c -s)

# Configure additional repositories.
# -----------------------------------------------------------------------------

if apt_add_key "573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62" "nginx"; then
	repo_nginx_url="http://nginx.org/packages/mainline/debian/"
	printf "${bold}Installing nginx repository... "
	printf ""`
		`"deb ${repo_nginx_url} ${lsb_codename} nginx\n"`
		`"deb-src ${repo_nginx_url} ${lsb_codename} nginx\n" \
		> "/etc/apt/sources.list.d/nginx.list"
	printf "${green}OK${normal}\n"
fi

if apt_add_key "9FD3B784BC1C6FC31A8A0A1C1655A0AB68576280" "NodeSource"; then
	repo_nodesource_url="https://deb.nodesource.com/node_5.x/"
	printf "${bold}Installing NodeSource repository... "
	printf ""`
		`"deb ${repo_nodesource_url} ${lsb_codename} main\n"`
		`"deb-src ${repo_nodesource_url} ${lsb_codename} main\n" \
		> "/etc/apt/sources.list.d/nodesource.list"
	printf "${green}OK${normal}\n"
fi

if apt_add_key "11E9DE8848F2B65222AA75B8D1820DB22A11534E" "WeeChat"; then
	repo_weechat_url="https://weechat.org/debian/"
	printf "${bold}Installing WeeChat repository... "
	printf ""`
		`"deb ${repo_weechat_url} ${lsb_codename} main\n"`
		`"deb-src ${repo_weechat_url} ${lsb_codename} main\n" \
		> "/etc/apt/sources.list.d/weechat.list"
	printf "${green}OK${normal}\n"
fi

# Update the system and install new packages.
# -----------------------------------------------------------------------------

if [ ${conf_packages} ]; then
	apt_update
	apt_upgrade
	apt_install "${conf_packages[@]}"
fi

# Configure and enable the firewall.
# -----------------------------------------------------------------------------

printf "${bold}Configuring firewall... "

if [ -d "/sys/class/net" ]; then
	interfaces="["
	
	# Add all network interfaces to the public firewall zone.
	for interface in /sys/class/net/*; do
		# Obtain the last part of the path (the interface name).
		interface=$(basename "${interface}")

		# Ignore the loopback interface.
		if [ "lo" == "${interface}" ]; then
			continue;
		fi

		# Add the interface the public firewall zone.
		firewall-cmd \
			--zone=public \
			--change-interface="${interface}" \
			--permanent >/dev/null 2>&1

		interfaces+="${interface},"
	done

	interfaces+="\b]"

	if firewall-cmd --reload >/dev/null 2>&1; then
		printf "${green}OK${normal} ${interfaces}\n"
	else
		printf "${red}FAILED${normal}\n"
	fi
else
	printf "${red}FAILED${normal}\n"
fi

# Create and configure user accounts.
# -----------------------------------------------------------------------------

printf "${bold}Creating users...${normal}\n"

# Create user accounts and SSH key pairs.
for user in "${conf_users[@]}"; do
	# Create user account.
	if ! adduser --disabled-password --gecos "" "${user}"; then
		continue;
	fi

	# Generate a secure password.
	password="$(pwgen 16 1)"
	echo "${user}:${password}" | chpasswd

	# Create SSH configuration directory.
	user_ssh_home="$(eval echo ~${user})/.ssh"
	mkdir -p "${user_ssh_home}"

	# Generate SSH key pair.
	if [ ! -e "${user_ssh_home}/id_rsa" ]; then
		ssh-keygen -q -N "" -t rsa -b 4096 \
			-C "${user}@${conf_hostname}" \
			-f "${user_ssh_home}/id_rsa"

		# Create default SSH configuration files.
		touch ${user_ssh_home}/{config,known_hosts}
		cp ${user_ssh_home}/id_rsa.pub \
			${user_ssh_home}/authorized_keys
	fi

	# Set secure permissions.
	chown -R ${user}:${user} ${user_ssh_home}
	chmod -R 600 ${user_ssh_home}
	chmod 700 ${user_ssh_home}

	printf \
		"${bold}Password for \"%s\" is \"%s\".${normal}\n" \
		"${user}" \
		"${password}"
done

# Grant sudo permissions to specified users.
for user in "${conf_sudoers[@]}"; do
	usermod -a -G sudo "${user}"
done

# Apply custom patches.
# -----------------------------------------------------------------------------

printf "${bold}Applying custom patches...${normal}\n"

# Patches annoying warning about a "precedence issue" in GNU Stow.
# https://bugzilla.redhat.com/show_bug.cgi?id=1226473
(cd / && patch -p0 -N) <<'EOF'
--- /usr/share/perl5/Stow.pm	2015-11-15 14:13:24.988791230 +0100
+++ /usr/share/perl5/Stow.pm	2015-11-15 14:14:50.901640819 +0100
@@ -1732,8 +1732,9 @@
     }
     elsif (-l $path) {
         debug(4, "  read_a_link($path): real link");
-        return readlink $path
-            or error("Could not read link: $path");
+        my $target = readlink $path
+            or error("Could not read link: $path ($!)");
+        return $target;
     }
     internal_error("read_a_link() passed a non link path: $path\n");
 }
EOF

# Print further instructions to be carried out by root.
# -----------------------------------------------------------------------------

printf "\n"`
	`" ${bold}TODO${normal}\n"`
	`" o Set passwords on the appropriate user accounts:\n"`
	`"   passwd <username>\n"`
	`" o Add your public keys to ~/.ssh/authorized_keys.\n"`
	`"   Failing to do this may lock you out.\n"`
	`" o Modify /etc/hosts to suit your needs.\n"`
	`" o Modify /etc/ssh/sshd_config:\n"`
	`"   1) Change PermitRootLogin to \"no\".\n"`
	`"   2) Change PasswordAuthentication to \"no\".\n"`
	`"   3) Restart the SSH service:\n"`
	`"      sudo systemctl restart sshd\n"`
	`" o Use firewalld to manage the firewall (man firewall-cmd).\n"`
	`"\n"

exit 0

# Further reading.
# -----------------------------------------------------------------------------
# - Terminal Colors With 'tput':
#   http://www.tldp.org/HOWTO/Bash-Prompt-HOWTO/x405.html
# - The Unofficial Bash Strict Mode:
#   http://redsymbol.net/articles/unofficial-bash-strict-mode
# - The Internal Field Separator (IFS):
#   http://stackoverflow.com/a/918931

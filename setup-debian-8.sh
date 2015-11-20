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
	"autossh"
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
	"xauth"
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

# Color escape codes.
bold=$(tput bold)
cyan=$(tput setaf 6)
normal=$(tput sgr0)
red=$(tput setaf 1)

# Make sure that the user is actually root.
# ----------------------------------------------------------------------

if [[ ${EUID} -ne 0 ]]; then
	printf ""`
		`"${red}${bold}error: "`
		`"${normal}must be run as ${bold}root${normal} "`
		`"${cyan}[you are $(whoami)]${normal}\n"

	exit 1;
fi

# Configure the system hostname.
# ----------------------------------------------------------------------
# The hostnamectl command is a part of systemd.

printf "${bold}Setting hostname to \"${conf_hostname}\"...${normal}\n"

if has hostnamectl; then
	hostnamectl set-hostname "${conf_hostname}"
else
	echo "${conf_hostname}" > /etc/hostname
	hostname -F /etc/hostname
fi

# Configure the system time zone.
# ----------------------------------------------------------------------

printf "${bold}Setting timezone to \"${conf_timezone}\"...${normal}\n"

echo "${conf_timezone}" > /etc/timezone
dpkg-reconfigure -f noninteractive tzdata

# Install third-party signing keys.
# ----------------------------------------------------------------------

printf "${bold}Installing nginx signing key...${normal}\n"

apt-key adv \
	--keyserver pgp.mit.edu \
	--recv-keys 573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62

printf "${bold}Installing WeeChat signing key...${normal}\n"

apt-key adv \
	--keyserver keys.gnupg.net \
	--recv-keys 11E9DE8848F2B65222AA75B8D1820DB22A11534E

# Configure additional repositories.
# ---------------------------------------------------------------------

repo_nginx_url="http://nginx.org/packages/mainline/debian/"
printf "${bold}Installing nginx repository...${normal}\n"
printf ""`
	`"deb ${repo_nginx_url} ${debian_codename} nginx\n"`
	`"deb-src ${repo_nginx_url} ${debian_codename} nginx\n" \
	> /etc/apt/sources.list.d/nginx.list

repo_weechat_url="http://weechat.org/debian/"
printf "${bold}Installing WeeChat repository...${normal}\n"
printf ""`
	`"deb ${repo_weechat_url} ${debian_codename} main\n"`
	`"deb-src ${repo_weechat_url} ${debian_codename} main\n" \
	> /etc/apt/sources.list.d/weechat.list

# Update the system and install new packages.
# ----------------------------------------------------------------------

printf "${bold}Updating package list...${normal}\n"
aptitude update

printf "${bold}Upgrading installed packages...${normal}\n"
aptitude upgrade -y

printf "${bold}Installing new packages...${normal}\n"
aptitude -y install ${conf_packages[@]}

# Configure and enable the firewall.
# ----------------------------------------------------------------------

printf "${bold}Configuring firewall...${normal}\n"

ufw default deny incoming
ufw default allow outgoing
ufw limit ssh/tcp
ufw --force enable

# Create and configure user accounts.
# ----------------------------------------------------------------------

printf "${bold}Creating users...${normal}\n"

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

# Apply custom patches.
# ----------------------------------------------------------------------

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
# ----------------------------------------------------------------------

printf "\n"`
	`" TODO\n"`
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
	`" o Use UFW to manage the firewall (man ufw).\n"`
	`"\n"

exit 0

# Further reading.
# ----------------------------------------------------------------------
# - Terminal Colors With 'tput':
#   http://www.tldp.org/HOWTO/Bash-Prompt-HOWTO/x405.html
# - The Unofficial Bash Strict Mode: 
#   http://redsymbol.net/articles/unofficial-bash-strict-mode
# - The Internal Field Separator (IFS):
#   http://stackoverflow.com/a/918931

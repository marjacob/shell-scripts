# Adding users to groups
This example adds the user `martin` to the group `sudo`.

	usermod -aG sudo martin

## Flags
- `-a` makes `-G` append to the group list instead of replacing it.
- `-G` takes a list of groups and adds the user to them.

# Creating system users
This example creates a system user for running the ZNC IRC bouncer.

	adduser --system --home /var/lib/znc --group --disabled-login --gecos "ZNC" znc

## Flags
- `--disabled-login` prevents anyone except `root` from using the account.
- `--gecos` sets the full name field of the user.
- `--group` will place the new system user in a new group with the same ID.
- `--home` sets the home directory of the system user. `/var/lib/...` is usually a good place.
- `--system` selects numeric identifiers from the `SYS_UID_MIN`-`SYS_UID_MAX` range.

# Moving home directories
This example moves the home directory of the user `znc` to `/mnt/home/znc`.

	usermod -m -d /mnt/home/znc znc

## Flags
- `-d` specifies the new home directory.
- `-m` moves the content of the previous home directory to the new location.

# Generating SSH keys
	
	ssh-keygen -q -N "" -t rsa -b 4096 -C "root@merlin" -f "/root/.ssh/id_rsa"

# Sources
- [Moving home directories](https://lists.debian.org/debian-user/2008/10/msg00335.html)
- [The difference between normal users and system users](http://unix.stackexchange.com/a/80279)

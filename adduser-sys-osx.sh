#!/bin/bash

# CURRENT
# https://github.com/marjacob/shell-scripts/blob/master/adduser-sys-osx.sh

# HISTORY
# 2014-09-01 mwf [https://gist.github.com/mwf/20cbb260ad2490d7faaa]
# 2013-08-22 par [http://serverfault.com/a/532860]

# Check that we are superuser (i.e. $(id -u) is zero)
# if (( $(id -u) )); then
# 	printf "This script needs to run as root\n"
# 	exit 1
# fi

if [[ -z "$1" ]]; then
	printf "Usage: $(basename $0) [username] [realname (optional)]\n"
	exit 1
fi

username=$1
realname="${2:-${username}}"

printf "Adding daemon user ${username} with real name \"${realname}\"\n"
exit 0

for (( uid = 500;; --uid )); do
	if ! id -u $uid &>/dev/null; then
		if ! dscl /Local/Default -ls Groups gid | grep -q [^0-9]$uid\$ ; then
			dscl /Local/Default -create Groups/_${username}
			dscl /Local/Default -create Groups/_${username} Password \*
			dscl /Local/Default -create Groups/_${username} PrimaryGroupID $uid
			dscl /Local/Default -create Groups/_${username} RealName "${realname}"
			dscl /Local/Default -create Groups/_${username} RecordName _${username} ${username}

			dscl /Local/Default -create Users/_${username}

			# Need home directory?
			# dscl /Local/Default -create Users/_${username} NFSHomeDirectory /var/empty
			dscl /Local/Default -create Users/_${username} NFSHomeDirectory /Users/_${username}
			dscl /Local/Default -create Users/_${username} Password \*
			dscl /Local/Default -create Users/_${username} PrimaryGroupID $uid
			dscl /Local/Default -create Users/_${username} RealName "${realname}"
			dscl /Local/Default -create Users/_${username} RecordName _${username} ${username}
			dscl /Local/Default -create Users/_${username} UniqueID $uid
			# Need shell access for the user?
			# dscl /Local/Default -create Users/_${username} UserShell /usr/bin/false
			dscl /Local/Default -create Users/_${username} UserShell /bin/bash

			dscl /Local/Default -delete /Users/_${username} AuthenticationAuthority
			dscl /Local/Default -delete /Users/_${username} PasswordPolicyOptions
			break
		fi
	fi
done

printf "Created system user ${username} (uid/gid $uid):\n"

dscl /Local/Default -read Users/_${username}

printf "\nYou can undo the creation of this user by issuing the following commands:\n"
printf "\tsudo dscl /Local/Default -delete Users/_${username}"
printf "\tsudo dscl /Local/Default -delete Groups/_${username}"

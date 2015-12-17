# Dependencies
Build dependencies for software on Debian 8.

## Kaiwa

	sudo aptitude install libldap2-dev uuid-dev

## Prosody
The following is required for the websocket module to work properly if the installed lua version is lower than 5.2.

	sudo aptitude install luarocks
	sudo luarocks install bit32

## ZNC
See the [ZNC installation manual](http://wiki.znc.in/Installation#Debian "ZNC installation manual").

	sudo aptitude install build-essential libicu-dev libperl-dev libssl-dev pkg-config


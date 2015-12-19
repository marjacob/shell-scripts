# Dependencies
Build dependencies for software on Debian 8.

## Kaiwa

	sudo aptitude install libldap2-dev uuid-dev
	
## nginx

	apt-key adv --keyserver "keys.gnupg.net" --recv-keys "573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62"
	printf "deb ${repo_nginx_url} ${lsb_codename} nginx\ndeb-src ${repo_nginx_url} ${lsb_codename} nginx\n" > "/etc/apt/sources.list.d/nginx.list"
	

## Prosody
The following is required for the websocket module to work properly if the installed lua version is lower than 5.2.

	sudo aptitude install luarocks
	sudo luarocks install bit32

## ZNC
See the [ZNC installation manual](http://wiki.znc.in/Installation#Debian "ZNC installation manual").

	sudo aptitude install build-essential libicu-dev libperl-dev libssl-dev pkg-config


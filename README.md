# This is a personal VPN service

About this project.  This utilizes the GitHub project
[kylemanna/docker-openvpn][upstream].  Why invent something when great quality
already exists?

The docker-compose file uses [kylemanna/docker-openvpn][upstream].

However, a multiarch minimal distroless openvpn is provided in
[Dockerfile](Dockerfile).  I also experimented with a Debian Dockerfile but it
is too complex to be worth using.

# Initializing the service for the first time

    docker-compose run --rm openvpn ovpn_genconfig -u udp://vpn.example.com
    docker-compose run --rm openvpn ovpn_initpki

# Starting the service after initializing

    docker-compose up -d

[upstream]: https://github.com/kylemanna/docker-openvpn

# This is a personal VPN service

For raspberry pi, see [Using minimal Dockerfile](#using-minimal-dockerfile).
You should manage certificates from a Desktop computer and copy over the
`openvpn.conf` to the raspi.

> **Pro tip:** It is better to manage your certificate authority from a
> different computer than your VPN host.  In case of compromise, you can
> regenerate your server configuration (revoke and re-issue) rotating the key
> and diffie-hellman parameters without needing to re-issue certificates to all
> of your clients.  On a raspberry pi, generating diffie-hellman parameters can
> take tens of minutes so doing it this way enables it to be pre-computed.

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

# Using minimal Dockerfile

Clone [my internal ca][my_internal_ca] and configure it.

```bash
git clone https://github.com/samrocketman/my_internal_ca
pushd ../my_internal_ca
./setup_ca.sh -subj '/C=US/ST=Some state/L=Some City/O=Some org/OU=Some department/CN=My Root CA'
./setup_ca.sh openvpn --dns-alts "yourdomain.example.com" --ip-alts "your public IP"
./client_cert.sh your-device-or-name-of-client
```

Generate server config.

    ./gen-conf.sh

Start the VPN service:

    ./ovpn.sh start

Stop the VPN service:

    ./ovpn.sh stop

If you wish to configure a NAT (not implemented, yet) run the following:

```bash
docker run \
    --cap-add NET_ADMIN \
    --rm \
    -v "$PWD"/openvpn/openvpn.conf:/server.conf \
    -w / \
    --name openvpn \
    --sysctl net.ipv6.conf.all.disable_ipv6=0 \
    --sysctl net.ipv6.conf.default.forwarding=1 \
    --sysctl net.ipv6.conf.all.forwarding=1 \
    -d \
    openvpn-min
```

[my_internal_ca]: https://github.com/samrocketman/my_internal_ca
[upstream]: https://github.com/kylemanna/docker-openvpn

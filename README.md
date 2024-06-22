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

A multiarch minimal distroless openvpn is provided in [Dockerfile](Dockerfile).

# Requirements

* Linux
* awk (GNU only)
* openssl
* sed (GNU coreutils only)

Not really requirements:

- docker: you don't need to use the Dockerfile to manage OpenVPN.  You can use
  this repository to generate your OpenVPN server and client configurations.
  Then, use it elsewhere without Docker.

Router port forwarding: on your raspberry pi the openvpn server will listen on
port 1194/TCP.  If possible, I suggest port forwarding 1194 -> 443.  By hosting
your VPN on port 443 you will always be able to connect through even the most
aggressive firewalls because it is disguised as an authenticated web server.

# Using minimal Dockerfile

Clone [my internal ca][my_internal_ca] and configure it.  Note: client certs
must start with `openvpn-` otherwise the server will reject certs.  This
certificate authority is designed for a managing multiple security chains; not
just openvpn.

```bash
git clone https://github.com/samrocketman/my_internal_ca
pushd ../my_internal_ca
./setup_ca.sh -subj '/C=US/ST=Some state/L=Some City/O=Some org/OU=Some department/CN=My Root CA'
./server_cert.sh --auth openvpn
./client_cert.sh openvpn-your-device
```

Generate server config.

    ./gen-conf.sh

Start the VPN service:

    ./ovpn.sh start

Stop the VPN service:

    ./ovpn.sh stop

Verifying your traffic routing with traceroute.  The first hop should be
`10.9.8.1`.

    sudo traceroute -T -p 80 example.com

# Environment variables

To minimize the amount of options you need to pass you can create a `.env` file
specifying default options for scripts.

`ovmn.sh` options in `.env`.

| Env var | Purpose |
| --- | --- |
| `strict_firewall` | Sets `ports_map` to `443:1194` to expose VPN on 443. |
| `ports_map` | Fully the docker ports mapping.  Default: `1194:1194` |
| `network_args` | A bash array for Docker networking arguments |

`gen-conf.sh` options in `.env`.

| Env var | Purpose |
| --- | --- |
| myCA | Location to CA generated by `my_internal_ca`. |
| `config_type` | Set to `server` (`-s`) or `client` (`-c`) |
| `client_remote` | Set remote VPN host or IP (`-r`) |
| `client_port` | Set remote VPN port (`-p`) |

Once you have your certificate authority setup, the following `.env`
configuration will make it a lot easier to setup new clients.

# `.env` recommendations

### Easier client config generation

```bash
config_type=client
client_remote=<remote vpn server IP or host>
client_port=<remote vpn server port>
```

With the above `.env` you can issue new client certificates and generate options
with minimal argumements.

    cd ../my_internal_ca/
    ./client_cert.sh openvpn-another-device
    cd -
    ./gen-conf.sh openvpn-another-device
    # find configuration in openvpn/openvpn-another-device.ovpn

### Connecting to docker compose HA consul and vault

If experimenting with
[docker-compose-ha-consul-vault-ui][docker-compose-ha-consul-vault-ui], then
you'll want the following `.env` config for `./ovpn.sh [start|stop|remove]`.

```bash
# ./ovpn.sh options
network_args=(
  --network docker-compose-ha-consul-vault-ui_internal
  --dns 172.16.238.2
  --ip 172.16.238.254
)
strict_firewall=true

# ./gen-conf.sh options
custom_dns=( 172.16.238.2 172.16.238.3 )
```

If experimenting with

# Password protect openvpn configurations

Before running `client_cert.sh` you can choose to set the `client_password`
environment variable or add the `-p` or `--password-prompt` option.

    ./client_cert.sh -p openvpn-another-device

[docker-compose-ha-consul-vault-ui]: https://github.com/samrocketman/docker-compose-ha-consul-vault-ui
[my_internal_ca]: https://github.com/samrocketman/my_internal_ca
[upstream]: https://github.com/kylemanna/docker-openvpn

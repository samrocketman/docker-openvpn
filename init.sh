if [ ! -f /etc/openvpn/ovpn_env.sh ]; then
  ovpn_genconfig -u udp://"${OVPN_DOMAIN:-vpn.gleske.net}"

fi

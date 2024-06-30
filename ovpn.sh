#!/bin/bash

declare -a network_args
[ ! -f .env ] || source .env

start() {
  if ! docker inspect -f . openvpn-min &> /dev/null; then
    docker build -t openvpn-min .
  fi

  if [ -n "${strict_firewall:-}" ]; then
    ports_map=443:1194/tcp
  else
    ports_map="${ports_map:-1194:1194}"
  fi

  if [ "${#network_args[@]}" -eq 0 ]; then
    if [ -z "$(docker network ls -q -f name=openvpn)" ]; then
      docker network create --driver=bridge --subnet=172.10.9.0/24 openvpn
    fi
    network_args=( --network openvpn )
  fi

  if [ -z "$(docker ps -a -q -f name=openvpn)" ]; then
    echo 'Created new openvpn service.' >&2
    docker run \
      -p "${ports_map}" \
      --cap-add NET_ADMIN \
      -v "$PWD"/openvpn/openvpn.conf:/server.conf \
      -w / \
      --name openvpn \
      "${network_args[@]}" \
      --sysctl net.ipv6.conf.all.disable_ipv6=0 \
      --sysctl net.ipv6.conf.default.forwarding=1 \
      --sysctl net.ipv6.conf.all.forwarding=1 \
      --sysctl net.ipv4.ip_forward=1 \
      -d \
      --restart always \
      openvpn-min
  else
    echo -n "Started "
    docker start openvpn
    echo >&2
    echo "Run command '$0 llog'" >&2
  fi
}

stop() {
  echo -n "Stopped "
  docker stop openvpn
}

case "${1:-start}" in
  start)
    start
    ;;
  stop|s)
    stop
    ;;
  restart|r)
    stop || true
    $0 remove || true
    start
    ;;
  remove|rm)
    docker rm -f openvpn
    if [ "${#network_args[@]}" -eq 0 ]; then
      docker network rm openvpn
    fi
    ;;
  log|logs|l)
    shift
    docker logs "$@" openvpn
    ;;
  llog|llogs|ll)
    $0 log | less
    ;;
  *)
    echo "ERROR: argument '$1' not supported." >&2
    echo "Usage: $0 [start|stop|restart|log|llog|log -f|remove]" >&2
    echo "Short usage (start no arguments): $0 [s|r|l|ll|l -f|rm]" >&2
    exit 1
    ;;
esac

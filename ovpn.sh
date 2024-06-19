#!/bin/bash

start() {
  if ! docker inspect -f . openvpn-min &> /dev/null; then
    docker build -t openvpn-min .
  fi

  if [ -z "$(docker ps -q -f name=openvpn)" ]; then
    docker run \
      -p 1194:1194 \
      --cap-add NET_ADMIN \
      --rm \
      -v "$PWD"/openvpn/openvpn.conf:/server.conf \
      -w / \
      --name openvpn \
      -d \
      openvpn-min
  else
    echo 'openvpn already started.' >&2
    echo >&2
    echo "Run command '$0 llog'" >&2
  fi
}

stop() {
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
    start
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
    echo "Usage: $0 [start|stop|restart|log|llog|log -f]" >&2
    echo "Short usage (start no arguments): $0 [s|r|l|ll|l -f]" >&2
    exit 1
    ;;
esac

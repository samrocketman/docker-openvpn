#!/bin/bash

if ! docker inspect -f . openvpn-min &> /dev/null; then
  docker build -t openvpn-min .
fi

if [ -z "$(docker ps -q -f name=openvpn)" ]; then
  docker run \
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
  echo 'Run command "docker logs openvpn"' >&2
fi

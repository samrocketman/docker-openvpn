#!/bin/bash
# Created by Sam Gleske
# Pop!_OS 22.04 LTS
# Linux 6.6.10-76060610-generic x86_64
# GNU bash, version 5.1.16(1)-release (x86_64-pc-linux-gnu)

set -euo pipefail

[ ! -f .env ] || source .env

myCA="${myCA:-../my_internal_ca/myCA}"

stderr() {
  if [ "$#" -gt 0 ]; then
    echo "$*" >&2
  else
    cat >&2
  fi
}

missing_files() {
cat <<'EOF' | stderr
Missing myca.crt, server cert, or server key.
  git clone https://github.com/samrocketman/my_internal_ca
  pushd ../my_internal_ca
  ./setup_ca.sh -subj '/C=US/ST=Some state/L=Some City/O=Some org/OU=Some department/CN=My Root CA'
  ./setup_ca.sh openvpn --dns-alts "yourdomain.example.com" --ip-alts "your public IP"
  ./client_cert.sh your-device-or-name-of-client
EOF
  stderr ''
  stderr "See also '$0 --help'"
  exit 1
}

filter_cert() {
  sed -e "s/${default_name}\\(\\.crt\\|\\.key\\)/${ovpn_cert}\\1/"
}

filter_crl() {
  if [ ! -f "${myCA}"/crl.pem ]; then
    sed -e '/crl\.pem/d' -e '/crl-verify/d'
  else
    cat
  fi
}

awk_script() {
cat <<'EOF'
$1 == "#" && $2 == "AWK" {
  spaces = $0
  gsub("^[^ \t].*$", "", spaces)
  cmd = "cat "$3
  while(cmd | getline) {
    print spaces$0
  }
  next
};
{
  print $0
}
EOF
}

substitute_with_awk() {
  awk "$(awk_script)"
}

helptext() {
cat <<'EOF'
SYNOPSIS
  gen-conf.sh [OPTIONS] CERTIFICATE_NAME
  gen-conf.sh -c -r REMOTE CERTIFICATE_NAME

DESCRIPTION
  An openvpn config generator for single server and multiple clients.

OPTIONS AND ARGUMENTS
  CERTIFICATE_NAME
    When generating a certificate for server or client via my_internal_ca, you
    give it a name for the certificate.

  Server or client is required.

    -s, --server
      Generate server ovpn config.
    -c, --client
      Generate client ovpn config.

  Client options

    -r REMOTE, --remote REMOTE
      Remote IP address or DNS name where the client should attempt to connect.
    -p PORT, --port PORT
      Remote port where client should attempt to connect.

EOF
}

# Replacement for envsubst; substitution via bash
envsubst() (
eval "
cat <<EOF
$(cat)
EOF
"
)

if type -P gawk &> /dev/null; then
  awk() { gawk "$@"; }
fi
if type -P gsed &> /dev/null; then
  sed() { gsed "$@"; }
fi

#
# MAIN
#
config_type="${config_type:-server}"
client_remote="${client_remote:-noremote}"
client_port="${client_port:-1194}"
export client_remote client_port
while [ "$#" -gt 0 ]; do
  case "${1:-}" in
    --server|-s)
      config_type=server
      shift
      ;;
    --client|-c)
      config_type=client
      shift
      ;;
    --remote|-r)
      client_remote="$2"
      shift
      shift
      ;;
    --port|-p)
      client_port="$2"
      shift
      shift
      ;;
    --help|-h)
      helptext
      exit 1
      ;;
    -*)
      stderr "Option '$1' not recognized."
      exit 1
      ;;
    *)
      break
      ;;
  esac
done

#
# ERROR CHECKING
#

if [ "$config_type" = server ]; then
  default_name=openvpn
else
  default_name=openvpn-client
fi
ovpn_cert="${1:-${default_name}}"
if [ "$config_type" = client ]; then
  if [ "$client_remote" = noremote ]; then
    stderr 'Must provide --remote option when creating client config.'
    stderr ''
    stderr "See also '$0 --help'"
    exit 1
  fi
  if ! openssl x509 -noout -subject -in \
      "${myCA}"/certs/"${ovpn_cert}".crt | \
      grep 'CN *= *openvpn-' > /dev/null; then
    stderr 'ERROR: Certificate name must start with "openvpn-".'
    exit 1
  fi
fi

if [ ! -f "${myCA}"/certs/"${ovpn_cert}".crt ] || \
   [ ! -f "${myCA}"/private/"${ovpn_cert}".key ] || \
   [ ! -f "${myCA}"/certs/myca.crt ]; then
  missing_files
fi

if [ ! -f dh.pem ]; then
  openssl dhparam -out dh.pem 2048
fi

if [ ! -f static.key ]; then
  if ! docker inspect -f . openvpn-min &> /dev/null; then
    docker build -t openvpn-min .
  fi
  docker run --rm openvpn-min \
    /bin/sh -c \
      'mkfifo x; cat x & openvpn --genkey secret x' > static.key
fi

if [ "$config_type" = server ]; then
  ext=conf
else
  ext=ovpn
fi

#
# CREATE CONFIGURATION
#
filter_cert < "$config_type".awk-template.conf | \
  filter_crl | \
  envsubst | \
  substitute_with_awk > openvpn/"${ovpn_cert}"."$ext" &&
    echo Configuration written to openvpn/"${ovpn_cert}"."$ext" ||
    rm openvpn/"${ovpn_cert}"."$ext"

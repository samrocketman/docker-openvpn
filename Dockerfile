FROM alpine as busybox
SHELL ["/bin/sh", "-exc"]
RUN \
  mkdir -p /base/etc /base/bin /base/root /base/tmp /base/var/tmp; \
  chmod 700 /base/root; \
  chmod 1777 /base/tmp /base/var/tmp; \
  apk add curl bash openvpn iptables

RUN \
  curl -sSfLo /usr/local/bin/copy-bin.sh https://raw.githubusercontent.com/samrocketman/home/main/bin/copy-bin.sh; \
  curl -sSfLo /usr/local/bin/download-utilities.sh https://raw.githubusercontent.com/samrocketman/yml-install-files/main/download-utilities.sh; \
  chmod 755 /usr/local/bin/*.sh

# openvpn server
RUN \
  copy-bin.sh -p /base -l /usr/sbin/openvpn; \
  copy-bin.sh -p /base -l /bin/busybox -L /bin:/sbin:/usr/bin:/usr/sbin; \
  apk info -L iptables libxtables libnftnl libmnl | grep -v 'contains:\|^$' | xargs tar c | tar -xC /base; \
  copy-bin.sh -p /base -l /sbin/$(readlink $(which iptables)) -L /bin:/sbin:/usr/bin:/usr/sbin; \
  cd /base/sbin; \
  ln -s ../bin/busybox ip

# init
RUN \
  mkdir scratch; \
  curl -sSfL https://raw.githubusercontent.com/samrocketman/yml-install-files/main/download-utilities.yml | \
  download-utilities.sh - dumb-init; \
  mv scratch/dumb-init /base/bin/

# minimal accounts
RUN \
  echo 'root:x:0:0:root:/root:/sbin/nologin' >> /base/etc/passwd; \
  echo 'root:x:0:root' >> /base/etc/group; \
  echo 'nobody:x:65534:65534:nobody:/:/sbin/nologin' >> /base/etc/passwd; \
  echo 'nobody:x:65534:' >> /base/etc/group

FROM scratch
COPY --from=busybox /base /
ENV ENV=/etc/profile
ENTRYPOINT ["/bin/dumb-init", "--"]
CMD [ \
  "/bin/sh", \
  "-ec", \
  "[ -e /dev/net/tun ] || (mkdir -p /dev/net; mknod /dev/net/tun c 10 200; ); iptables -t nat -A POSTROUTING -s 10.9.8.0/24 -o eth0 -j MASQUERADE; openvpn --config /server.conf"]

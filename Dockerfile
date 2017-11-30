FROM opsani/skopos:edge

COPY ad-join wbstart /skopos/

RUN apt-get update && \
 echo 'APT::Install-Recommends "false";' >/etc/apt/apt.conf.d/99no-recommends && \
 DEBIAN_FRONTEND=noninteractive apt-get install -y krb5-user && \
 apt-get install -y winbind libpam-winbind libnss-winbind && \
 awk '($1=="passwd:" || $1=="group:") && ! /winbind/ { print $0,"winbind"; next} {print}' /etc/nsswitch.conf >/tmp/nsswitch.conf.new && \
 cat /tmp/nsswitch.conf.new >/etc/nsswitch.conf

ENTRYPOINT ["/skopos/wbstart"]

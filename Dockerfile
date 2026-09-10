FROM debian:11-slim

ARG UTM_DEB=u-trans-4.2.0-2644-i386.deb
ENV DEBIAN_FRONTEND=noninteractive TZ=Europe/Moscow

# UTM needs legacy 32-bit OpenSSL 1.1, which is available in Debian 11.
# Debian 11 is archived, so use its immutable archive and accept its expired
# Release metadata instead of the no-longer-refreshed security mirror.
RUN sed -i \
      -e 's|deb.debian.org/debian-security|archive.debian.org/debian-security|g' \
      -e 's|deb.debian.org/debian|archive.debian.org/debian|g' \
      -e '/bullseye-updates/d' \
      /etc/apt/sources.list \
    && dpkg --add-architecture i386 \
    && apt-get -o Acquire::Check-Valid-Until=false update \
    && apt-get install -y --no-install-recommends \
      acl ca-certificates libccid libc6:i386 libncurses5:i386 \
      libpcsclite1 libpcsclite1:i386 libssl1.1:i386 libstdc++6:i386 \
      libusb-1.0-0 libxmu6:i386 libxt6:i386 pcsc-tools pcscd \
      supervisor tzdata usbutils \
    && rm -rf /var/lib/apt/lists/* \
    && ln -snf /usr/share/zoneinfo/${TZ} /etc/localtime \
    && echo ${TZ} > /etc/timezone

RUN printf '%s\n' '#!/bin/sh' 'exit 101' > /usr/sbin/policy-rc.d \
    && chmod +x /usr/sbin/policy-rc.d
COPY ${UTM_DEB} /tmp/utm.deb
RUN dpkg -i /tmp/utm.deb \
    && rm -f /tmp/utm.deb /usr/sbin/policy-rc.d \
    && mkdir -p /var/log/supervisor /run/pcscd

COPY supervisord.conf /etc/supervisor/supervisord.conf
COPY transport.conf /etc/supervisor/conf.d/utm.conf
COPY pcscd.conf /etc/pcscd.conf
COPY entrypoint.sh /usr/local/bin/utm-entrypoint
RUN chmod 0755 /usr/local/bin/utm-entrypoint

EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/utm-entrypoint"]
CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/supervisord.conf"]

FROM debian:trixie-slim

ARG UTM_DEB=u-trans-4.2.0-2644-i386.deb
ENV DEBIAN_FRONTEND=noninteractive TZ=Europe/Moscow

# UTM 4.2.0-2644 is used successfully on Debian 12/13.  Use current
# Trixie repositories and its 32-bit compatibility libraries.
RUN dpkg --add-architecture i386 \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
      acl ca-certificates libccid libc6:i386 libncurses6:i386 \
      libpcsclite1 libpcsclite1:i386 libssl3:i386 libstdc++6:i386 \
      libusb-1.0-0 libxmu6:i386 libxt6:i386 pcsc-tools pcscd \
      supervisor tzdata usbutils \
    && rm -rf /var/lib/apt/lists/* \
    && ln -snf /usr/share/zoneinfo/${TZ} /etc/localtime \
    && echo ${TZ} > /etc/timezone

RUN printf '%s\n' '#!/bin/sh' 'exit 101' > /usr/sbin/policy-rc.d \
    && chmod +x /usr/sbin/policy-rc.d
COPY ${UTM_DEB} /tmp/utm.deb
# The UTM post-install script calls supervisorctl and treats a missing socket
# as an installation error. Start the distro Supervisor briefly for that step.
RUN mkdir -p /var/log/supervisor /run/pcscd \
    && /usr/bin/supervisord -c /etc/supervisor/supervisord.conf \
    && dpkg -i /tmp/utm.deb \
    && /usr/bin/supervisorctl shutdown \
    && rm -f /tmp/utm.deb /usr/sbin/policy-rc.d

COPY supervisord.conf /etc/supervisor/supervisord.conf
COPY transport.conf /etc/supervisor/conf.d/utm.conf
COPY pcscd.conf /etc/pcscd.conf
COPY entrypoint.sh /usr/local/bin/utm-entrypoint
RUN chmod 0755 /usr/local/bin/utm-entrypoint

EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/utm-entrypoint"]
CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/supervisord.conf"]

#!/bin/sh
set -eu

# UTM chooses its PKCS#11 configuration only while the package post-install
# script executes. Repeat it after the host Rutoken is available in Docker.
if [ -x /var/lib/dpkg/info/u-trans.postinst ]; then
    # The vendor script finishes with `supervisorctl status`. Supervisor has
    # not started at this point, so its exit code is expected and ignored.
    /var/lib/dpkg/info/u-trans.postinst configure || true
fi

# The vendor post-install script starts pcscd through init.d. Supervisor owns
# pcscd in this container, so stop that temporary daemon and remove its socket
# before starting Supervisor to prevent a second-daemon collision.
if [ -x /etc/init.d/pcscd ]; then
    /etc/init.d/pcscd stop || true
fi
rm -f /run/pcscd/pcscd.comm /run/pcscd/pcscd.pid

exec "$@"

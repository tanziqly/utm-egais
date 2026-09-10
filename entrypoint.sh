#!/bin/sh
set -eu

# UTM chooses its PKCS#11 configuration only while the package post-install
# script executes. Repeat it after the host Rutoken is available in Docker.
if [ -x /var/lib/dpkg/info/u-trans.postinst ]; then
    /var/lib/dpkg/info/u-trans.postinst configure || {
        echo "UTM token configuration failed; inspect USB access and logs." >&2
        exit 1
    }
fi
exec "$@"

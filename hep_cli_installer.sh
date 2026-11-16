#!/bin/bash
#
# Installs hep_cli (package hepic-installer) from the QXIP packagecloud repo qxip/hepic.
#
# The repo is written with the same file names and key path that packagecloud's own
# setup script uses, because that is what "hep_cli --full-install" runs later:
#   Debian/Ubuntu: /etc/apt/sources.list.d/qxip_hepic_any.list
#                  signed-by /etc/apt/keyrings/qxip_hepic-archive-keyring.gpg
#   RHEL family:   /etc/yum.repos.d/qxip_hepic_rpm_any.repo
# hep_cli then overwrites the same files instead of adding a second definition of the
# same repo, which on Debian/Ubuntu makes apt fail with
# "Conflicting values set for option Signed-By".
#
# Older versions of this script wrote qxip_hepic.list + /etc/apt/keyrings/hepic.gpg
# (or qxip_hepic.repo). They are removed first, so re-running this script also
# repairs a host that already has the conflict.

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

set -o pipefail

APT_LIST=/etc/apt/sources.list.d/qxip_hepic_any.list
APT_KEYRING=/etc/apt/keyrings/qxip_hepic-archive-keyring.gpg
YUM_REPO=/etc/yum.repos.d/qxip_hepic_rpm_any.repo

fail() {
    echo -e "${RED}ERROR: $*${NC}" >&2
    exit 1
}

if [ "$EUID" -ne 0 ]; then
    fail "Run this installer as root."
fi

if [ -f /etc/redhat-release ]; then
    FAMILY=rhel
    PKG=$(command -v dnf || command -v yum)
    [ -n "$PKG" ] || fail "Neither dnf nor yum was found."
elif [ -f /etc/debian_version ]; then
    FAMILY=debian
else
    fail "Unsupported OS: neither /etc/redhat-release nor /etc/debian_version exists."
fi

## The key can be passed in HEP_CLI_KEY; otherwise prompt for it. When stdin is not a
## terminal (e.g. "curl ... | bash", where stdin is the script itself) ask on /dev/tty.
key="${HEP_CLI_KEY:-}"
if [ -z "$key" ]; then
    echo -e "Please insert the provided key to install hep_cli:"
    if [ ! -t 0 ] && { : < /dev/tty; } 2> /dev/null; then
        read -r key < /dev/tty
    else
        read -r key
    fi
fi
key="$(printf '%s' "$key" | tr -d '[:space:]')"
if [ -z "$key" ]; then
    fail "No key was entered."
fi
## Only characters that are safe in the repo URL and in the files written below
case "$key" in
    *[!A-Za-z0-9_-]*) fail "The key may contain only letters, digits, '-' and '_'. Check that it was copied correctly." ;;
esac

## Remove the repo files written by older versions of this script
remove_legacy() {
    local f
    for f in "$@"; do
        if [ -e "$f" ]; then
            echo "Removing $f (written by an older hep_cli installer)"
            rm -f "$f"
        fi
    done
}

if [ "$FAMILY" == rhel ]; then
    remove_legacy /etc/yum.repos.d/qxip_hepic.repo

    # curl is not needed here: dnf/yum fetch the repo themselves. Installing it would
    # also conflict with curl-minimal on RHEL/Rocky 9 images.
    "$PKG" install -y sudo || fail "Could not install sudo."

    cat > "$YUM_REPO" << EOF
[qxip_hepic_rpm_any]
name=qxip_hepic_rpm_any
baseurl=https://${key}:@packagecloud.io/qxip/hepic/rpm_any/rpm_any/\$basearch
repo_gpgcheck=1
gpgcheck=0
enabled=1
gpgkey=https://${key}:@packagecloud.io/qxip/hepic/gpgkey
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
metadata_expire=300

[qxip_hepic_rpm_any-source]
name=qxip_hepic_rpm_any-source
baseurl=https://${key}:@packagecloud.io/qxip/hepic/rpm_any/rpm_any/SRPMS
repo_gpgcheck=1
gpgcheck=0
enabled=1
gpgkey=https://${key}:@packagecloud.io/qxip/hepic/gpgkey
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
metadata_expire=300
EOF

    echo "Reading the qxip_hepic repository..."
    if ! "$PKG" -q makecache -y --disablerepo='*' --enablerepo='qxip_hepic_rpm_any'; then
        fail "The qxip_hepic repository could not be read. Check the key and the connection to packagecloud.io."
    fi

    echo -e "************************************************************"
    echo -e "\t ${GREEN} Installing Hepic-Installer a.k.a hep_cli ${NC}\n\t\t"
    echo -e "************************************************************"
    "$PKG" install -y hepic-installer || fail "hepic-installer could not be installed."

else
    remove_legacy /etc/apt/sources.list.d/qxip_hepic.list /etc/apt/keyrings/hepic.gpg

    apt-get install -y sudo gnupg curl || fail "Could not install sudo, gnupg and curl."
    install -m 0755 -d /etc/apt/keyrings

    if ! curl -fsSL "https://${key}:@packagecloud.io/qxip/hepic/gpgkey" | gpg --batch --yes --dearmor -o "$APT_KEYRING"; then
        rm -f "$APT_KEYRING"
        fail "The repository key could not be downloaded. Check the key and the connection to packagecloud.io."
    fi
    chmod 0644 "$APT_KEYRING"

    cat > "$APT_LIST" << EOF
deb [signed-by=${APT_KEYRING}] https://${key}:@packagecloud.io/qxip/hepic/any/ any main
deb-src [signed-by=${APT_KEYRING}] https://${key}:@packagecloud.io/qxip/hepic/any/ any main
EOF

    echo "Running apt-get update..."
    if ! apt-get update; then
        echo -e "${RED}WARNING: apt-get update reported errors (see above). Trying to install hep_cli anyway.${NC}" >&2
    fi

    echo -e "************************************************************"
    echo -e "\t ${GREEN} Installing Hepic-Installer a.k.a hep_cli ${NC}\n\t\t"
    echo -e "************************************************************"
    # hepic-installer ships /bin/hep_cli as a conffile. dpkg does not put back a conffile
    # that was deleted while the package was removed but not purged, so a plain install
    # can leave the host without hep_cli. --reinstall also covers a package that is still
    # installed, and --force-confmiss re-creates the missing file.
    apt-get install -y --reinstall -o Dpkg::Options::=--force-confmiss hepic-installer \
        || fail "hepic-installer could not be installed. Check the apt-get update output above."
fi

command -v hep_cli > /dev/null || fail "hepic-installer was installed but hep_cli was not found."
echo -e "${GREEN}hep_cli is installed. Next step: hep_cli --full-install${NC}"

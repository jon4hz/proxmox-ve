#!/bin/bash
set -euxo pipefail

# configure apt for non-interactive mode.
export DEBIAN_FRONTEND=noninteractive

# switch to the non-enterprise repository.
# see https://pve.proxmox.com/wiki/Package_Repositories
dpkg-divert --divert /etc/apt/sources.list.d/pve-enterprise.list.distrib.disabled --rename --add /etc/apt/sources.list.d/pve-enterprise.list
dpkg-divert --divert /etc/apt/sources.list.d/ceph.list.distrib.disabled --rename --add /etc/apt/sources.list.d/ceph.list
echo "deb http://download.proxmox.com/debian/pve $(. /etc/os-release && echo "$VERSION_CODENAME") pve-no-subscription" >/etc/apt/sources.list.d/pve.list
echo "deb http://download.proxmox.com/debian/ceph-reef $(. /etc/os-release && echo "$VERSION_CODENAME") no-subscription" >/etc/apt/sources.list.d/ceph.list

# switch the apt mirror to adfinis
cat >/etc/apt/sources.list <<'EOF'
deb http://pkg.adfinis-on-exoscale.ch/debian/ bookworm main non-free non-free-firmware contrib
deb-src http://pkg.adfinis-on-exoscale.ch/debian/ bookworm main non-free non-free-firmware contrib

deb http://security.debian.org/ bookworm-security main
deb-src http://security.debian.org/ bookworm-security main

deb http://pkg.adfinis-on-exoscale.ch/debian/ bookworm-updates main contrib non-free non-free-firmware
deb-src http://pkg.adfinis-on-exoscale.ch/debian/ bookworm-updates main contrib non-free non-free-firmware
EOF

# update only (no upgrade since we want to use this image to test automated cluster upgrades)
apt-get update

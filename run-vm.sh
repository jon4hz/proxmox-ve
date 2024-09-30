#!/bin/bash

cat /etc/os-release

apt update && apt install -y qemu-system packer

make build-libvirt

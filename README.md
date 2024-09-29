This builds an up-to-date [Proxmox VE](https://www.proxmox.com/en/proxmox-ve) Vagrant Base Box.

Currently this targets Proxmox VE 8.

# Usage

Create the base box as described in the section corresponding to your provider.

If you want to troubleshoot the packer execution see the `.log` file that is created in the current directory.

After the example vagrant environment is started, you can access the [Proxmox Web Interface](https://10.10.10.2:8006/) with the default `root` user and password `vagrant`.

For a cluster example see [rgl/proxmox-ve-cluster-vagrant](https://github.com/rgl/proxmox-ve-cluster-vagrant).

## libvirt

Create the base box:

```bash
make build-libvirt
```

Add the base box as suggested in make output:

```bash
vagrant box add -f proxmox-ve-amd64 proxmox-ve-amd64-libvirt.box
```

Start the example vagrant environment with:

```bash
cd example
vagrant up --no-destroy-on-error --provider=libvirt
```

## Proxmox

Set the Proxmox VE details:

```bash
cat >secrets-proxmox.sh <<EOF
export PROXMOX_URL='https://192.168.1.21:8006/api2/json'
export PROXMOX_USERNAME='root@pam'
export PROXMOX_PASSWORD='vagrant'
export PROXMOX_NODE='pve'
EOF
source secrets-proxmox.sh
```

Create the template:

```bash
make build-proxmox
```

**NB** There is no way to use the created template with vagrant (the [vagrant-proxmox plugin](https://github.com/telcat/vagrant-proxmox) is no longer compatible with recent vagrant versions). Instead, use packer or terraform.

## Packer build performance options

To improve the build performance you can use the following options.

### Accelerate build time with Apt Caching Proxy

To speed up package downloads, you can specify an apt caching proxy 
(e.g. [apt-cacher-ng](https://www.unix-ag.uni-kl.de/~bloch/acng/))
by defining the environment variables `APT_CACHE_HOST` (default: undefined)
and `APT_CACHE_PORT` (default: 3124).

Example:

```bash
APT_CACHE_HOST=10.10.10.100 make build-libvirt
```

### Decrease disk wear by using temporary memory file-system

To decrease disk wear (and potentially reduce io times),
you can use `/dev/shm` (temporary memory file-system) as `output_directory` for Packer builders.
Your system must have enough available memory to store the created virtual machine.

Example:

```bash
PACKER_OUTPUT_BASE_DIR=/dev/shm make build-libvirt
```

Remember to also define `PACKER_OUTPUT_BASE_DIR` when you run `make clean` afterwards.

## Variables override

Some properties of the virtual machine and the Proxmox VE installation can be overridden.
Take a look at `proxmox-ve.pkr.hcl`, `variable` blocks, to get an idea which values can be
overridden. Do not override `iso_url` and `iso_checksum` as the `boot_command`s might be
tied to a specific Proxmox VE version.

Create the base box:

```bash
make build-libvirt VAR_FILE=example.pkrvars.hcl
```

The following content of `example.pkrvars.hcl`:

* sets the initial disk size to 128 GB
* sets the initial memory to 4 GB
* sets the Packer output base directory to /dev/shm
* uses all default shell provisioners (see [`./provisioners`](./provisioners)) and a
  custom one for german localisation

```hcl
disk_size = 128 * 1024
memory = 4 * 1024
output_base_dir = "/dev/shm"
shell_provisioner_scripts = [
  "provisioners/apt_proxy.sh",
  "provisioners/upgrade.sh",
  "provisioners/network.sh",
  "provisioners/localisation-de.sh",
  "provisioners/reboot.sh",
  "provisioners/provision.sh",
]
```

# Packer boot_command

The Proxmox installation is [automatically configured](https://pve.proxmox.com/wiki/Automated_Installation) using the [`answer.toml` file](answer.toml), but to trigger the automatic installation, this environment has to nudge the default Proxmox installation ISO to use the [`answer.toml` file](answer.toml) through the packer `boot_command` interface. This is quite fragile, so be aware when you change anything. The following table describes the current steps and corresponding answers.

| step                                    | boot_command                                                                               |
|----------------------------------------:|--------------------------------------------------------------------------------------------|
| select "Advanced Options"               | `<end><enter>`                                                                             |
| select "Install Proxmox VE (Automated)" | `<down><down><down><enter>`                                                                |
| wait for the shell prompt               | `<wait1m>`                                                                                 |
| do the installation                     | `proxmox-fetch-answer partition >/run/automatic-installer-answers<enter><wait>exit<enter>` |

packer {
  required_plugins {
    # see https://github.com/hashicorp/packer-plugin-qemu
    qemu = {
      version = "1.1.0"
      source  = "github.com/hashicorp/qemu"
    }
    # see https://github.com/hashicorp/packer-plugin-proxmox
    proxmox = {
      version = "1.2.0"
      source  = "github.com/hashicorp/proxmox"
    }
    # see https://github.com/hashicorp/packer-plugin-vagrant
    vagrant = {
      version = "1.1.5"
      source  = "github.com/hashicorp/vagrant"
    }
  }
}

variable "vagrant_box" {
  type = string
}

variable "cpus" {
  type    = number
  default = 2
}

variable "memory" {
  type    = number
  default = 2 * 1024
}

variable "disk_size" {
  type    = number
  default = 20 * 1024
}

variable "iso_url" {
  type    = string
  default = "http://download.proxmox.com/iso/proxmox-ve_8.2-2.iso"
}

variable "iso_checksum" {
  type    = string
  default = "sha256:c96ad84eacbbcef299ab8f407f9602f832abb5ceb08a9aa288c1e1164df2da97"
}

variable "proxmox_node" {
  type    = string
  default = env("PROXMOX_NODE")
}

variable "apt_cache_host" {
  type    = string
  default = env("APT_CACHE_HOST")
}

variable "apt_cache_port" {
  type    = string
  default = env("APT_CACHE_PORT")
}

variable "output_base_dir" {
  type    = string
  default = env("PACKER_OUTPUT_BASE_DIR")
}

variable "shell_provisioner_scripts" {
  type = list(string)
  default = [
    "provisioners/apt_proxy.sh",
    "provisioners/network.sh",
    "provisioners/update.sh",
    "provisioners/localisation-ch.sh",
    "provisioners/reboot.sh",
    "provisioners/provision.sh",
  ]
}

source "qemu" "proxmox-ve-amd64" {
  accelerator  = "kvm"
  machine_type = "q35"
  cpus         = var.cpus
  memory       = var.memory
  qemuargs = [
    ["-cpu", "host"],
  ]
  headless            = true
  use_default_display = false
  net_device          = "virtio-net"
  format              = "qcow2"
  disk_size           = var.disk_size
  disk_interface      = "virtio-scsi"
  disk_cache          = "unsafe"
  disk_discard        = "unmap"
  iso_url             = var.iso_url
  iso_checksum        = var.iso_checksum
  output_directory    = "${var.output_base_dir}/output-{{build_name}}"
  ssh_username        = "root"
  ssh_password        = "vagrant"
  ssh_timeout         = "60m"
  cd_label            = "proxmox-ais"
  cd_files            = ["answer.toml"]
  boot_wait           = "5s"
  boot_command = [
    # select Advanced Options.
    "<end><enter>",
    # select Install Proxmox VE (Automated).
    "<down><down><down><enter>",
    # wait for the shell prompt.
    "<wait1m>",
    # do the installation.
    "proxmox-fetch-answer partition >/run/automatic-installer-answers<enter><wait>exit<enter>",
  ]
  shutdown_command = "poweroff"
}

source "qemu" "proxmox-ve-uefi-amd64" {
  accelerator  = "kvm"
  machine_type = "q35"
  efi_boot     = true
  cpus         = var.cpus
  memory       = var.memory
  qemuargs = [
    ["-cpu", "host"],
  ]
  headless            = true
  use_default_display = false
  net_device          = "virtio-net"
  format              = "qcow2"
  disk_size           = var.disk_size
  disk_interface      = "virtio-scsi"
  disk_cache          = "unsafe"
  disk_discard        = "unmap"
  iso_url             = var.iso_url
  iso_checksum        = var.iso_checksum
  ssh_username        = "root"
  ssh_password        = "vagrant"
  ssh_timeout         = "60m"
  cd_label            = "proxmox-ais"
  cd_files            = ["answer.toml"]
  boot_wait           = "10s"
  boot_command = [
    # select Advanced Options.
    "<end><enter>",
    # select Install Proxmox VE (Automated).
    "<down><down><down><enter>",
    # wait for the shell prompt.
    "<wait1m>",
    # do the installation.
    "proxmox-fetch-answer partition >/run/automatic-installer-answers<enter><wait>exit<enter>",
  ]
  shutdown_command = "poweroff"
}

source "proxmox-iso" "proxmox-ve-amd64" {
  template_name            = "template-proxmox-ve"
  template_description     = "See https://github.com/rgl/proxmox-ve"
  tags                     = "proxmox-ve;template"
  insecure_skip_tls_verify = true
  node                     = var.proxmox_node
  machine                  = "q35"
  bios                     = "seabios"
  cpu_type                 = "host"
  cores                    = var.cpus
  memory                   = var.memory
  vga {
    type   = "qxl"
    memory = 16
  }
  network_adapters {
    model  = "virtio"
    bridge = "vmbr0"
  }
  scsi_controller = "virtio-scsi-single"
  disks {
    type         = "scsi"
    io_thread    = true
    ssd          = true
    discard      = true
    disk_size    = "${var.disk_size}M"
    storage_pool = "local-lvm"
  }
  iso_storage_pool = "local"
  iso_url          = var.iso_url
  iso_checksum     = var.iso_checksum
  unmount_iso      = true
  additional_iso_files {
    cd_label         = "proxmox-ais"
    cd_files         = ["answer.toml"]
    unmount          = true
    iso_storage_pool = "local"
  }
  os           = "l26"
  ssh_username = "root"
  ssh_password = "vagrant"
  ssh_timeout  = "60m"
  boot_wait    = "30s"
  boot_command = [
    # select Advanced Options.
    "<end><enter>",
    # select Install Proxmox VE (Automated).
    "<down><down><down><enter>",
    # wait for the shell prompt.
    "<wait1m>",
    # do the installation.
    "proxmox-fetch-answer partition >/run/automatic-installer-answers<enter><wait>exit<enter>",
    # wait for the installation to finish.
    "<wait4m>",
    # login.
    "root<enter><wait5s>vagrant<enter><wait5s>",
    # install the guest agent.
    "rm -f /etc/apt/sources.list.d/{pve-enterprise,ceph}.list<enter>",
    "apt-get update<enter><wait1m>",
    "apt-get install -y qemu-guest-agent<enter><wait30s>",
    "systemctl start qemu-guest-agent<enter><wait>",
  ]
}

source "proxmox-iso" "proxmox-ve-uefi-amd64" {
  template_name            = "template-proxmox-ve-uefi"
  template_description     = "See https://github.com/rgl/proxmox-ve"
  tags                     = "proxmox-ve-uefi;template"
  insecure_skip_tls_verify = true
  node                     = var.proxmox_node
  machine                  = "q35"
  bios                     = "ovmf"
  efi_config {
    efi_storage_pool = "local-lvm"
  }
  cpu_type = "host"
  cores    = var.cpus
  memory   = var.memory
  vga {
    type   = "qxl"
    memory = 16
  }
  network_adapters {
    model  = "virtio"
    bridge = "vmbr0"
  }
  scsi_controller = "virtio-scsi-single"
  disks {
    type         = "scsi"
    io_thread    = true
    ssd          = true
    discard      = true
    disk_size    = "${var.disk_size}M"
    storage_pool = "local-lvm"
  }
  iso_storage_pool = "local"
  iso_url          = var.iso_url
  iso_checksum     = var.iso_checksum
  unmount_iso      = true
  additional_iso_files {
    iso_storage_pool = "local"
    cd_label         = "proxmox-ais"
    cd_files         = ["answer.toml"]
    unmount          = true
  }
  os           = "l26"
  ssh_username = "root"
  ssh_password = "vagrant"
  ssh_timeout  = "60m"
  boot_wait    = "30s"
  boot_command = [
    # select Advanced Options.
    "<end><enter>",
    # select Install Proxmox VE (Automated).
    "<down><down><down><enter>",
    # wait for the shell prompt.
    "<wait1m>",
    # do the installation.
    "proxmox-fetch-answer partition >/run/automatic-installer-answers<enter><wait>exit<enter>",
    # wait for the installation to finish.
    "<wait4m>",
    # login.
    "root<enter><wait5s>vagrant<enter><wait5s>",
    # install the guest agent.
    "rm -f /etc/apt/sources.list.d/{pve-enterprise,ceph}.list<enter>",
    "apt-get update<enter><wait1m>",
    "apt-get install -y qemu-guest-agent<enter><wait30s>",
    "systemctl start qemu-guest-agent<enter><wait>",
  ]
}

build {
  sources = [
    "source.qemu.proxmox-ve-amd64",
    "source.qemu.proxmox-ve-uefi-amd64",
    "source.proxmox-iso.proxmox-ve-amd64",
    "source.proxmox-iso.proxmox-ve-uefi-amd64",
  ]

  provisioner "shell" {
    expect_disconnect = true
    environment_vars = [
      "apt_cache_host=${var.apt_cache_host}",
      "apt_cache_port=${var.apt_cache_port}",
    ]
    scripts = var.shell_provisioner_scripts
  }

  post-processor "vagrant" {
    only = [
      "qemu.proxmox-ve-amd64",
    ]
    output               = var.vagrant_box
    vagrantfile_template = "Vagrantfile.template"
  }

  post-processor "vagrant" {
    only = [
      "qemu.proxmox-ve-uefi-amd64",
    ]
    output               = var.vagrant_box
    vagrantfile_template = "Vagrantfile-uefi.template"
  }
}

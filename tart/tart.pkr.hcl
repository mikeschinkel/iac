packer {
  required_plugins {
    tart = {
      version = ">= 0.5.3"
      source  = "github.com/cirruslabs/tart"
    }
  }
}
variable "distro_name" {}           // e.g. debian
variable "distro_version" {}        // e.g. 12.6.0
variable "vm_name" {}               // e.g. k1
variable "ssh_username" {}          // e.g. admin
variable "ssh_password" {}          // e.g. admin

locals {
  packages = "curl jq yq git unzip make net-tools tree"
  home_dir = "/home/${var.ssh_username}"
}

source "tart-cli" "tart" {
  vm_base_name = "ghcr.io/cirruslabs/debian:latest"
  vm_name      = "${var.vm_name}"
  cpu_count    = 2
  memory_gb    = 4
  disk_size_gb = 40
  headless     = false
  ssh_username = "${var.ssh_username}"
  ssh_password = "${var.ssh_password}"
  ssh_timeout  = "1h30m"
  disable_vnc = false
}

build {
  sources = ["source.tart-cli.tart"]

  # Ensure /tmp/scripts directory exists on the VM
  provisioner "shell" {
    inline = [
      "mkdir -p /home/${var.ssh_username}/scripts"
    ]
  }

  # Copy all scripts to the VM
  provisioner "file" {
    source      = "./scripts/"
    destination = "${local.home_dir}/scripts/"
  }

  # Run each script on the VM as root
  provisioner "shell" {
    inline = [
      "echo Chmoding .sh scripts in ${local.home_dir}/scripts...",
      "cd ${local.home_dir}/scripts",
      "echo PWD=$(pwd)",
      "find .",
      "chmod +x *.sh",
      "echo '${var.ssh_password}' | sudo -k ./configure.sh '${var.vm_name}' '${var.ssh_username}' '${var.ssh_password}' '${local.packages}'",
      "echo Shell provisioner finished",
    ]
  }

}
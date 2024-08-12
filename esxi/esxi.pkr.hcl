packer {
  required_plugins {
    vmware = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/vmware"
    }
  }
}
variable "distro_name" {}           // e.g. debian
variable "distro_version" {}        // e.g. 12.6.0
variable "guest_os_type" {}         // e.g. debian9_64Guest
variable "host_output_dir" {}       // e.g. /Volumes/Tech/ISOs/linux
variable "remote_datastore" {}      // e.g. ds
variable "network_name" {}          // e.g. nw
variable "shutdown_command" {}      // e.g. sudo systemctl poweroff
variable "boot_command" {}          // e.g. ["<esc><wait>", "install <wait>", ... "<enter><wait>"]
variable "vnc_port" {}              // e.g. 5900
variable "esxi_host" {}             // e.g. esxi.local
variable "guest_build_dir" {}       // e.g. .
variable "esxi_username" {}         // e.g. esxi_user
variable "iso_filename" {}          // e.g. debian-12.6.0-amd64-DVD-1.iso
variable "iso_checksum" {}          // e.g. 856daaf85bcc538ae9c5d011eea4c84864157b3397062586b6f59e938eeb010d
variable "esxi_password" {          // e.g. not-a-real-password
  type = string
  sensitive = true
}

locals {
  output_format = "ovf"
  vnc_password = "this-is-temporary"
  vm_name = "${var.distro_name}-${var.distro_version}"
  iso_root = "../iso"
  iso_filepath = "${local.iso_root}/${var.iso_filename}"
  output_file = "${local.vm_name}.${local.output_format}"
  output_directory = "${var.host_output_dir}/${var.distro_name}/${var.distro_version}/${local.output_format}"
  output_filepath = "${local.output_directory}/${local.output_file}"
  upload_filepath = "vmfs/volumes/${var.remote_datastore}/${local.output_file}"
}

source "vmware-iso" "debian-12" {
  #iso_url      = "https://cdimage.debian.org/debian-cd/current/amd64/iso-dvd/${local.iso_filename}"
  #iso_url           = "/Volumes/Tech/ISOs/linux/debian/12.6.0/${local.iso_filename}"
  iso_url           = "${local.iso_filepath}"
  iso_checksum      = "${var.iso_checksum}"

  vm_name       = "${local.vm_name}"
  guest_os_type = "${var.guest_os_type}"
  disk_size     = 40960
  memory        = 16384
  cpus          = 2
  ssh_username = "packer"
  ssh_password = "packer"
  ssh_timeout  = "1h30m"

  http_directory = "http"

  # SSH configuration for ESXi server
  remote_type      = "esx5"
  remote_host      = "${var.esxi_host}"
  remote_datastore = "${var.remote_datastore}"
  remote_username  = "${var.esxi_username}"
  remote_password  = "${var.esxi_password}"
  network_name     = "${var.network_name}"

  shutdown_command = "${var.shutdown_command}"
  boot_command     = "${var.boot_command}"

  output_directory = "${local.output_directory}"
  format = "${local.output_format}"
  remote_output_directory = "${var.guest_build_dir}/${local.vm_name}"
  keep_registered = false

  vnc_over_websocket = true
  insecure_connection = true

  vmx_data = {
    "RemoteDisplay.vnc.enabled" = "TRUE"
    "RemoteDisplay.vnc.port" = "${var.vnc_port}"
    "RemoteDisplay.vnc.password" = "${local.vnc_password}"
  }

}

#TODO: Check to ensure ${var.vm_name} is not an existing VM
build {
  sources = ["source.vmware-iso.debian-12"]


  # Ensure local output dir
  provisioner "shell-local" {
    inline = [
      "rm -rf ${local.output_directory}",
      "mkdir -p ${local.output_directory}"
    ]
  }

  # Disable ESXi firewall before provisioning
  provisioner "shell-local" {
    environment_vars = [
      "ESXI_FIREWALL_ACTION=disable",
      "ESXI_HOST=${var.esxi_host}",
    ]
    script = "./scripts/host/configure-esxi-firewall.sh"
  }

  # Ensure /tmp/scripts directory exists on the VM
  provisioner "shell" {
    inline = [ "mkdir -p /tmp/scripts" ]
  }

  # Copy all scripts to the VM
  provisioner "file" {
    source      = "scripts/guest/"
    destination = "/tmp/scripts/"
  }

  # Run each script on the VM as root
  provisioner "shell" {
    inline = [
      "echo Chmoding .sh scripts in /tmp/scripts...",
      "chmod +x /tmp/scripts/*.sh",
#       "for script in /tmp/scripts/*.sh; do $script; done",
      "echo Shell provisioner finished"
    ]
  }

  # Re-enable ESXi firewall after provisioning
  post-processor "shell-local" {
    environment_vars = [
      "ESXI_FIREWALL_ACTION=enable",
      "ESXI_HOST=${var.esxi_host}",
    ]
    script = "./scripts/host/configure-esxi-firewall.sh"
  }
}

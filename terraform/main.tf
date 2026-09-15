terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.6.14"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

# -------------------- REDE --------------------
resource "libvirt_network" "k8s_network" {
  name      = "k8s-network-devops"
  mode      = "nat"
  addresses = [var.lab_network_cidr]
  autostart = true

  dns {
    enabled = true
  }
}

# -------------------- IMAGEM BASE --------------------
resource "libvirt_volume" "base_image" {
  name   = "base-image-devops.qcow2"
  pool   = "default"
  source = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
  format = "qcow2"
}

# -------------------- CLOUD-INIT DISKS --------------------
resource "libvirt_cloudinit_disk" "controlplane_init" {
  name      = "controlplane-init-devops.iso"
  pool      = "default"
  user_data = templatefile("${path.module}/cloud-init.yaml", { hostname = "controlplane" })
}

resource "libvirt_cloudinit_disk" "worker_init" {
  count     = var.worker_count
  name      = "worker-${count.index + 1}-init-devops.iso"
  pool      = "default"
  user_data = templatefile("${path.module}/cloud-init.yaml", { hostname = "worker-${count.index + 1}" })
}

# -------------------- VOLUMES DE DISCO --------------------
resource "libvirt_volume" "controlplane" {
  name           = "k8s-controlplane-devops.qcow2"
  base_volume_id = libvirt_volume.base_image.id
  pool           = "default"
  size           = 42949672960 # 40GB
}

resource "libvirt_volume" "worker" {
  count          = var.worker_count
  name           = "k8s-worker-${count.index + 1}-devops.qcow2"
  base_volume_id = libvirt_volume.base_image.id
  pool           = "default"
  size           = 21474836480 # 20GB
}

# -------------------- DOMAINS --------------------
resource "libvirt_domain" "controlplane" {
  name      = "k8s-controlplane-devops"
  memory    = var.controlplane_memory_mb
  vcpu      = var.controlplane_vcpu
  cloudinit = libvirt_cloudinit_disk.controlplane_init.id

  cpu { mode = "host-passthrough" }

  network_interface {
    network_id     = libvirt_network.k8s_network.id
    hostname       = "controlplane"
    wait_for_lease = true
  }

  disk { volume_id = libvirt_volume.controlplane.id }
}

resource "libvirt_domain" "worker" {
  count     = var.worker_count
  name      = "k8s-worker-${count.index + 1}-devops"
  memory    = var.worker_memory_mb
  vcpu      = var.worker_vcpu
  cloudinit = libvirt_cloudinit_disk.worker_init[count.index].id

  cpu { mode = "host-passthrough" }

  network_interface {
    network_id     = libvirt_network.k8s_network.id
    hostname       = "worker-${count.index + 1}"
    wait_for_lease = true
  }

  disk {
    volume_id = libvirt_volume.worker[count.index].id
  }
}

# -------------------- INVENTÁRIO ANSIBLE --------------------
resource "local_file" "ansible_inventory" {
  filename = "../ansible/inventory.ini"

  content = <<-EOT
[controlplane]
${libvirt_domain.controlplane.name} ansible_host=${libvirt_domain.controlplane.network_interface[0].addresses[0]}

[workers]
%{for worker in libvirt_domain.worker}
${worker.name} ansible_host=${worker.network_interface[0].addresses[0]}
%{endfor}

[k8s_cluster:children]
controlplane
workers

[all:vars]
ansible_user=ubuntu
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
ansible_ssh_pass=123456
EOT
}

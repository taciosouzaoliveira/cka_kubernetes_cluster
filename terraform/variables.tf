variable "lab_network_cidr" {
  description = "CIDR da rede NAT do lab (evite conflito com outras redes libvirt)"
  type        = string
  default     = "10.17.4.0/24"
}

variable "controlplane_memory_mb" {
  type    = number
  default = 3072
}

variable "controlplane_vcpu" {
  type    = number
  default = 2
}

variable "worker_memory_mb" {
  type    = number
  default = 2048
}

variable "worker_vcpu" {
  type    = number
  default = 2
}

variable "worker_count" {
  type    = number
  default = 2
}

variable "ssh_public_key_path" {
  description = "Chave pública SSH instalada no usuário ubuntu das VMs"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "ssh_private_key_path" {
  description = "Chave privada correspondente, usada pelo Ansible"
  type        = string
  default     = "~/.ssh/id_ed25519"
}

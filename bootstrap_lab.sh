#!/usr/bin/env bash
# =============================================================================
# bootstrap_lab.sh
# Recria a estrutura do lab CKA/Cilium no Dell (192.168.100.10)
# Uso: bash bootstrap_lab.sh
# =============================================================================
set -euo pipefail

LAB_ROOT="${HOME}/cka_kubernetes_cluster"
echo ">>> Criando lab em: ${LAB_ROOT}"

# -----------------------------------------------------------------------------
# 0. Pré-requisitos
# -----------------------------------------------------------------------------
if ! command -v terraform >/dev/null 2>&1; then
  echo "!! terraform não encontrado. Instale antes de continuar."
  echo "   sudo apt install -y terraform   (ou baixe do site oficial)"
  exit 1
fi

if ! command -v virsh >/dev/null 2>&1; then
  echo "!! libvirt/virsh não encontrado. Instale:"
  echo "   sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients"
  exit 1
fi

# -----------------------------------------------------------------------------
# 1. Estrutura de pastas
# -----------------------------------------------------------------------------
mkdir -p "${LAB_ROOT}"/{ansible,terraform,k8s-manifests,history_audit}
touch "${LAB_ROOT}/k8s-manifests/.gitkeep" "${LAB_ROOT}/history_audit/.gitkeep"

cd "${LAB_ROOT}"

# -----------------------------------------------------------------------------
# 2. cloud-init.yaml
# -----------------------------------------------------------------------------
cat > terraform/cloud-init.yaml <<'EOF'
#cloud-config
hostname: ${hostname}
fqdn: ${hostname}.k8s.local
manage_etc_hosts: true

users:
  - name: ubuntu
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: users, admin, sudo
    shell: /bin/bash
    lock-passwd: false

ssh_pwauth: true

chpasswd:
  list: |
    ubuntu:123456
  expire: False

package_update: true
package_upgrade: false

packages:
  - qemu-guest-agent
  - python3
  - python3-pip

runcmd:
  - systemctl start qemu-guest-agent
  - systemctl enable qemu-guest-agent
EOF

# -----------------------------------------------------------------------------
# 3. terraform/variables.tf
# -----------------------------------------------------------------------------
cat > terraform/variables.tf <<'EOF'
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
EOF

# -----------------------------------------------------------------------------
# 4. terraform/terraform.tfvars (ajuste aqui conforme o Dell)
# -----------------------------------------------------------------------------
cat > terraform/terraform.tfvars <<'EOF'
lab_network_cidr       = "10.17.4.0/24"
controlplane_memory_mb = 3072
controlplane_vcpu      = 2
worker_memory_mb       = 2048
worker_vcpu            = 2
worker_count           = 2
EOF

# -----------------------------------------------------------------------------
# 5. terraform/main.tf
# -----------------------------------------------------------------------------
cat > terraform/main.tf <<'EOF'
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
EOF

# -----------------------------------------------------------------------------
# 6. ansible/inventory.ini (placeholder — Terraform sobrescreve)
# -----------------------------------------------------------------------------
cat > ansible/inventory.ini <<'EOF'
[controlplane]
# preenchido pelo terraform apply

[workers]
# preenchido pelo terraform apply

[k8s_cluster:children]
controlplane
workers

[all:vars]
ansible_user=ubuntu
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
ansible_ssh_pass=123456
EOF

# -----------------------------------------------------------------------------
# 7. ansible/playbook.yml  (K8s v1.35 + pause:3.10)
# -----------------------------------------------------------------------------
cat > ansible/playbook.yml <<'EOF'
---
# =================================================================================
# PLAY 1: PREPARAR TODOS OS NÓS
# =================================================================================
- name: Preparar todos os nós (Control Plane e Workers)
  hosts: k8s_cluster
  become: yes

  handlers:
    - name: Restart containerd
      service:
        name: containerd
        state: restarted

  tasks:
    - name: Desabilitar swap imediatamente
      command: swapoff -a
      when: ansible_swaptotal_mb > 0

    - name: Remover swap do fstab
      lineinfile:
        path: /etc/fstab
        regexp: '.*swap.*'
        state: absent

    - name: Configurar módulos do Kernel
      copy:
        dest: /etc/modules-load.d/k8s.conf
        content: |
          overlay
          br_netfilter

    - name: Carregar módulos do kernel
      modprobe:
        name: "{{ item }}"
        state: present
      loop:
        - overlay
        - br_netfilter

    - name: Configurar parâmetros sysctl do Kubernetes
      copy:
        dest: /etc/sysctl.d/k8s.conf
        content: |
          net.bridge.bridge-nf-call-iptables  = 1
          net.bridge.bridge-nf-call-ip6tables = 1
          net.ipv4.ip_forward                 = 1

    - name: Aplicar sysctl
      command: sysctl --system

    - name: Instalar dependências básicas
      apt:
        name:
          - apt-transport-https
          - ca-certificates
          - curl
          - gnupg
          - lsb-release
        state: present
        update_cache: yes

    - name: Criar diretório de keyrings
      file:
        path: /etc/apt/keyrings
        state: directory
        mode: '0755'

    # -----------------------------
    # Kubernetes Repo  ->  v1.35
    # -----------------------------
    - name: Adicionar chave GPG do Kubernetes (v1.35)
      shell: |
        curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.35/deb/Release.key \
        | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
      args:
        creates: /etc/apt/keyrings/kubernetes-apt-keyring.gpg

    - name: Adicionar repositório Kubernetes (v1.35)
      apt_repository:
        repo: deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.35/deb/ /
        state: present
        filename: kubernetes

    - name: Instalar Containerd e Kubernetes
      apt:
        name:
          - containerd
          - kubelet
          - kubeadm
          - kubectl
        state: present
        update_cache: yes

    - name: Garantir que o diretório /etc/containerd exista
      file:
        path: /etc/containerd
        state: directory
        mode: '0755'

    - name: Gerar configuração padrão do containerd
      command: containerd config default
      register: containerd_config
      changed_when: false

    - name: Configurar containerd para Kubernetes
      copy:
        dest: /etc/containerd/config.toml
        content: |
          {{ containerd_config.stdout
             | regex_replace('SystemdCgroup = false', 'SystemdCgroup = true')
             | regex_replace('sandbox_image = ".*"', 'sandbox_image = "registry.k8s.io/pause:3.10"')
          }}
      notify: Restart containerd

    - name: Fixar versões do Kubernetes
      command: apt-mark hold kubelet kubeadm kubectl
      changed_when: false

# =================================================================================
# PLAY 2: INICIALIZAR CONTROL PLANE
# =================================================================================
- name: Inicializar Control Plane
  hosts: controlplane
  become: yes

  tasks:
    - name: Verificar se o cluster já foi inicializado
      stat:
        path: /etc/kubernetes/admin.conf
      register: k8s_initialized

    - name: Inicializar cluster Kubernetes
      command: >
        kubeadm init
        --pod-network-cidr=10.244.0.0/16
        --apiserver-advertise-address={{ ansible_default_ipv4.address }}
      when: not k8s_initialized.stat.exists

    - name: Criar diretório kube do root
      file:
        path: /root/.kube
        state: directory

    - name: Copiar kubeconfig para root
      copy:
        src: /etc/kubernetes/admin.conf
        dest: /root/.kube/config
        remote_src: yes

    - name: Instalar Flannel (CNI leve)
      command: kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
      environment:
        KUBECONFIG: /root/.kube/config
      when: not k8s_initialized.stat.exists

    - name: Gerar comando de join
      command: kubeadm token create --print-join-command
      register: join_command

    - name: Armazenar comando de join global
      set_fact:
        k8s_join_cmd: "{{ join_command.stdout }}"
      run_once: true

# =================================================================================
# PLAY 3: UNIR WORKERS AO CLUSTER
# =================================================================================
- name: Unir Workers ao Cluster
  hosts: workers
  become: yes

  tasks:
    - name: Verificar se o worker já faz parte do cluster
      stat:
        path: /etc/kubernetes/kubelet.conf
      register: worker_joined

    - name: Executar kubeadm join
      command: >
        {{ hostvars[groups['controlplane'][0]].k8s_join_cmd }}
        --ignore-preflight-errors=Mem
      when:
        - not worker_joined.stat.exists
        - hostvars[groups['controlplane'][0]].k8s_join_cmd is defined
EOF

# -----------------------------------------------------------------------------
# 8. lab_up.sh
# -----------------------------------------------------------------------------
cat > lab_up.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

echo ">>> [1/3] Terraform apply"
cd terraform
terraform init -upgrade
terraform apply -auto-approve
cd ..

echo ">>> [2/3] Aguardando SSH nas VMs"
sleep 20

echo ">>> [3/3] Ansible playbook"
cd ansible
ansible-playbook -i inventory.ini playbook.yml
cd ..

echo ">>> Lab pronto. Use: ssh ubuntu@\$(grep controlplane -A1 ansible/inventory.ini | tail -1 | awk '{print \$2}' | cut -d= -f2)"
EOF
chmod +x lab_up.sh

# -----------------------------------------------------------------------------
# 9. lab_down.sh
# -----------------------------------------------------------------------------
cat > lab_down.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/terraform"

echo ">>> Destruindo lab (VMs, volumes, rede)"
terraform destroy -auto-approve

echo ">>> Limpando ISOs de cloud-init órfãos"
sudo rm -f /var/lib/libvirt/images/*-init-devops.iso 2>/dev/null || true

echo ">>> Lab destruído."
EOF
chmod +x lab_down.sh

# -----------------------------------------------------------------------------
# 10. README.md
# -----------------------------------------------------------------------------
cat > README.md <<'EOF'
# Lab CKA / Cilium — Home Lab Dell

Provisionamento do cluster Kubernetes (kubeadm + Flannel) via Terraform + Ansible.

## Estrutura
- `terraform/`  → VMs libvirt (controlplane + N workers)
- `ansible/`    → preparação dos nós + kubeadm init + join
- `k8s-manifests/` → YAMLs de estudo
- `lab_up.sh`   → sobe tudo
- `lab_down.sh` → destrói tudo

## Uso rápido
```bash
./lab_up.sh          # provisiona + configura o cluster
./lab_down.sh        # destrói o lab

#!/usr/bin/env bash
# Provisiona as VMs com Terraform e monta o cluster com Ansible.
set -euo pipefail
cd "$(dirname "$0")"

SSH_KEY="${HOME}/.ssh/id_ed25519.pub"
if [ ! -f "${SSH_KEY}" ]; then
  echo "!! Chave SSH ${SSH_KEY} não encontrada."
  echo "   Gere com: ssh-keygen -t ed25519"
  echo "   Ou ajuste ssh_public_key_path em terraform/terraform.tfvars"
  exit 1
fi

echo ">>> [1/2] Terraform apply"
terraform -chdir=terraform init -upgrade
terraform -chdir=terraform apply -auto-approve

echo ">>> [2/2] Ansible playbook (aguarda o SSH das VMs antes de configurar)"
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml

CP_IP="$(terraform -chdir=terraform output -raw controlplane_ip)"
echo ">>> Lab pronto. Acesse com: ssh ubuntu@${CP_IP}"

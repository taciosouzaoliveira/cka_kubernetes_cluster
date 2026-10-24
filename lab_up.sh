#!/usr/bin/env bash
# Provisiona as VMs com Terraform e monta o cluster com Ansible.
set -euo pipefail
cd "$(dirname "$0")"

# Mesmos caminhos de chave que o Terraform vai usar (default, TF_VAR_* ou tfvars)
source scripts/chave_ssh.sh
for chave in "${SSH_PUB_KEY}" "${SSH_PRIV_KEY}"; do
  if [ ! -f "${chave}" ]; then
    echo "!! Chave SSH ${chave} não encontrada."
    echo "   Gere com: ssh-keygen -t ed25519"
    echo "   Ou ajuste ssh_public_key_path e ssh_private_key_path em terraform/terraform.tfvars"
    exit 1
  fi
done
echo ">>> Chave SSH: ${SSH_PUB_KEY}"

echo ">>> [1/2] Terraform apply"
terraform -chdir=terraform init -upgrade
terraform -chdir=terraform apply -auto-approve

echo ">>> [2/2] Ansible playbook (aguarda o SSH das VMs antes de configurar)"
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml

CP_IP="$(terraform -chdir=terraform output -raw controlplane_ip)"
echo ">>> Lab pronto. Acesse com: ssh ubuntu@${CP_IP}"

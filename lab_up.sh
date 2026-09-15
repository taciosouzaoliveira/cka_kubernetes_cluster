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

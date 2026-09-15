#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/terraform"

echo ">>> Destruindo lab (VMs, volumes, rede)"
terraform destroy -auto-approve

echo ">>> Limpando ISOs de cloud-init órfãos"
sudo rm -f /var/lib/libvirt/images/*-init-devops.iso 2>/dev/null || true

echo ">>> Lab destruído."

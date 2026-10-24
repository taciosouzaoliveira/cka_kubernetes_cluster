#!/usr/bin/env bash
# =============================================================================
# bootstrap_lab.sh
# Prepara o host para rodar o lab: confere ferramentas, libvirt e chave SSH.
# Os arquivos do projeto vêm do próprio repositório (git clone).
# Uso: ./bootstrap_lab.sh
# =============================================================================
set -uo pipefail

FALHAS=0

checar() {
  local cmd="$1" dica="$2"
  if command -v "$cmd" >/dev/null 2>&1; then
    echo "[ok]    $cmd"
  else
    echo "[falta] $cmd  ->  $dica"
    FALHAS=$((FALHAS + 1))
  fi
}

echo ">>> Ferramentas"
checar terraform        "instale pelo repositório oficial da HashiCorp"
checar virsh            "sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients"
checar ansible-playbook "sudo apt install -y ansible"
checar mkisofs          "sudo apt install -y genisoimage (usado pelo provider libvirt no cloud-init)"

echo ""
echo ">>> libvirt"
if sudo virsh pool-info default >/dev/null 2>&1; then
  echo "[ok]    storage pool 'default'"
else
  echo "[falta] storage pool 'default'  ->  sudo virsh pool-define-as default dir --target /var/lib/libvirt/images && sudo virsh pool-start default && sudo virsh pool-autostart default"
  FALHAS=$((FALHAS + 1))
fi

echo ""
echo ">>> Chave SSH"
if [ -f "${HOME}/.ssh/id_ed25519.pub" ]; then
  echo "[ok]    ${HOME}/.ssh/id_ed25519.pub"
else
  echo "[falta] chave SSH  ->  ssh-keygen -t ed25519"
  FALHAS=$((FALHAS + 1))
fi

echo ""
if [ "$FALHAS" -eq 0 ]; then
  echo ">>> Host pronto. Rode ./lab_up.sh"
else
  echo ">>> $FALHAS pendência(s). Resolva e rode este script de novo."
  exit 1
fi

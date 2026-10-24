#!/usr/bin/env bash
# Acompanha o provisionamento do lab: imagens, processos e VMs.
# Encerre com Ctrl+C.
while true; do
  clear
  echo "===== $(date '+%H:%M:%S') ====="
  echo ""
  echo "--- Imagem base ---"
  ls -lh /var/lib/libvirt/images/base-image-devops.qcow2 2>/dev/null || echo "  (ainda não existe)"
  echo ""
  echo "--- Arquivos mais recentes do pool ---"
  ls -lht /var/lib/libvirt/images/ 2>/dev/null | head -10
  echo ""
  echo "--- Processos ativos ---"
  ps aux | grep -E "terraform|qemu|genisoimage" | grep -v grep | awk '{print $11, $12, $13}' | head -10
  echo ""
  echo "--- VMs libvirt ---"
  sudo virsh list --all
  sleep 3
done

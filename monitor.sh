cat > ~/monitor_lab.sh <<'EOF'
#!/usr/bin/env bash
while true; do
  clear
  echo "===== $(date '+%H:%M:%S') ====="
  echo ""
  echo "--- Imagem base ---"
  ls -lh /var/lib/libvirt/images/base-image-devops.qcow2 2>/dev/null || echo "  (ainda não existe)"
  echo ""
  echo "--- Todos os arquivos ---"
  ls -lht /var/lib/libvirt/images/ 2>/dev/null | head -10
  echo ""
  echo "--- Processos ativos ---"
  ps aux | grep -E "terraform|qemu|genisoimage" | grep -v grep | awk '{print $11, $12, $13}' | head -10
  echo ""
  echo "--- VMs libvirt ---"
  sudo virsh list --all
  sleep 3
done
EOF
chmod +x ~/monitor_lab.sh
~/monitor_lab.sh

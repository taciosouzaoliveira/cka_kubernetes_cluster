#!/bin/bash
echo "🚀 Iniciando o cluster Kubernetes..."
for vm in $(sudo virsh list --all --name | grep 'k8s-'); do
    state=$(sudo virsh domstate "$vm" 2>/dev/null)
    if [ "$state" = "desligado" ] || [ "$state" = "shut off" ]; then
        echo "-> Ligando: $vm"
        sudo virsh start "$vm" > /dev/null
    else
        echo "-> $vm já está em execução."
    fi
done
echo "✅ Processo concluído!"

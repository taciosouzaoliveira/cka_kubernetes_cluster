#!/usr/bin/env bash
# Envia desligamento gracioso (ACPI) para as VMs do cluster.
echo ">>> Desligando o cluster Kubernetes de forma graciosa"
for vm in $(sudo virsh list --name | grep 'k8s-'); do
    echo "-> Enviando sinal de desligamento para: $vm"
    sudo virsh shutdown "$vm" > /dev/null
done
echo ">>> Comandos de desligamento enviados."

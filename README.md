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

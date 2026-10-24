# ☸️ CKA Kubernetes Cluster Home Lab

Este projeto implementa a automação completa de um cluster Kubernetes (estudo para a certificação CKA) utilizando infraestrutura como código (IaC) e gerenciamento de configuração. O lab é provisionado sobre VMs Libvirt (Dell Home Lab).

## 🚀 Arquitetura do Projeto

A solução é dividida em três camadas principais para garantir modularidade e reprodutibilidade:

1. **Infraestrutura (Terraform):** Provisionamento automatizado de Máquinas Virtuais via Libvirt, incluindo a configuração de `cloud-init` para a preparação inicial dos nós.
2. **Configuração (Ansible):** Automação da instalação do runtime de container, preparação do sistema operacional, inicialização do cluster via `kubeadm` e join dos nós workers.
3. **Orquestração (Kubernetes):** Cluster configurado com Flannel como CNI, pronto para a implantação de manifestos de estudo.

## 📂 Estrutura de Diretórios

```text
.
├── ansible/               # Playbooks de configuração e inventário dos nós
├── terraform/             # Código IaC para provisionamento das VMs Libvirt
├── k8s-manifests/          # Repositório de YAMLs e manifestos para estudos CKA
├── bootstrap_lab.sh       # Script de inicialização do ambiente
├── lab_up.sh              # Provisiona a infra e configura o cluster do zero
├── lab_down.sh            # Destrói completamente a infraestrutura
├── liga_cluster.sh        # Inicia as VMs do cluster (Power On)
├── desliga_cluster.sh     # Desliga as VMs do cluster (Power Off)
└── monitor.sh              # Utilitários de monitoramento do lab
```

## 🛠️ Como Utilizar

### Pré-requisitos
- Libvirt / KVM instalado e configurado.
- Terraform instalado.
- Ansible instalado.

### Fluxo de Trabalho

**1. Provisionamento Total (Primeira vez ou Reset):**
Para criar toda a infraestrutura e configurar o cluster automaticamente:
```bash
chmod +x *.sh
./lab_up.sh
```

**2. Gestão do Ciclo de Vida das VMs:**
Se você já provisionou o lab e deseja apenas ligar ou desligar as máquinas sem destruir a infraestrutura:
```bash
./liga_cluster.sh    # Iniciar VMs
./desliga_cluster.sh  # Parar VMs
```

**3. Limpeza Total:**
Para remover todas as VMs e recursos criados pelo Terraform:
```bash
./lab_down.sh
```

## 📖 Notas de Estudo (CKA)
Os manifestos localizados em `/k8s-manifests` são utilizados para praticar os tópicos do exame, incluindo:
- Troubleshooting de nós e pods.
- Gestão de RBAC e NetworkPolicies.
- Backup e Restore de etcd.
- Scheduling avançado (Taints/Tolerations, Affinity).

---
⭐ *Projeto desenvolvido para fins de estudo e laboratório pessoal.*

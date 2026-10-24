# 📜 Relatório de Intervenção Técnica: Cluster Kubernetes Home Lab

**Data:** 24 de Outubro de 2026
**Ambiente:** Home Lab Dell (Libvirt + Terraform + Ansible)
**Engenheiro:** Tácio Souza / Claude Code
**Status Final:** 🟢 Operacional

---

## 1. Resumo Executivo
O presente documento detalha as atividades de organização de repositório, manutenção de infraestrutura e resolução de incidentes no cluster Kubernetes destinado aos estudos das certificações CKA, CKAD e CKS. O foco principal foi a estabilização do componente ArgoCD ApplicationSet Controller.

## 2. Atividades de Organização e DevOps
Para adequar o projeto a padrões de portfólio profissional e boas práticas de GitOps, foram realizadas as seguintes melhorias:

- **Implementação de `.gitignore`**: Prevenção de upload de arquivos sensíveis (`.tfvars`) e arquivos de estado do Terraform (`.tfstate`), evitando vazamento de segredos e conflitos de infraestrutura.
- **Limpeza de Artefatos**: Remoção de arquivos temporários e logs de histórico (`history_*`, `teste.sh`) que poluíam a raiz do projeto.
- **Documentação Profissional**: Criação de um `README.md` detalhado, descrevendo a arquitetura de camadas (IaC $\rightarrow$ Config Management $\rightarrow$ Orquestração) e o guia de operação do laboratório.
- **Versionamento**: Sincronização do estado local com o repositório remoto no GitHub.

## 3. Análise e Resolução de Incidentes (Troubleshooting)

### Incidente: CrashLoopBackOff no ArgoCD ApplicationSet Controller

#### **A. Sintomas**
O pod `argocd-applicationset-controller` apresentava falhas consecutivas de inicialização, permanecendo no estado `CrashLoopBackOff`.

#### **B. Fluxo de Diagnóstico**
1. **Inspeção de Eventos**: `kubectl describe pod` revelou que o container iniciava e encerrava rapidamente.
2. **Análise de Logs**: `kubectl logs` identificou o erro crítico:
   > `"error":"failed to get restmapping: no matches for kind \"ApplicationSet\" in version \"argoproj.io/v1alpha1\""`
3. **Identificação da Causa Raiz**: O controlador tentava gerenciar recursos do tipo `ApplicationSet`, porém o **Custom Resource Definition (CRD)** correspondente não estava instalado no cluster.

#### **C. Processo de Remediação**
- **Tentativa 1 (`kubectl apply`)**: Falhou devido ao erro `metadata.annotations: Too long`. O manifesto do CRD excedia o limite de 262.144 bytes permitido para a anotação `last-applied-configuration`.
- **Solução Definitiva (`kubectl create`)**: Utilizou-se o comando `kubectl create` para instalar o CRD. Diferente do `apply`, o `create` não gera a anotação de configuração anterior, permitindo a instalação de manifestos volumosos.

#### **D. Verificação de Sucesso**
- Validação da existência do CRD: `kubectl get crd applicationsets.argoproj.io` $\rightarrow$ **OK**.
- Verificação de saúde dos pods: `kubectl get pods -n argocd` $\rightarrow$ **STATUS: Running**.

---

## 4. Conclusões e Recomendações
O ambiente encontra-se estável e apto para a simulação de cenários de prova.

**Recomendações para evoluções futuras:**
1. **Recursos de QoS**: Definir `requests` e `limits` para os pods do ArgoCD para evitar expulsões por falta de memória (`OOMKilled`).
2. **GitOps Flow**: Migrar a instalação de CRDs para dentro do repositório de infraestrutura para evitar a necessidade de intervenções manuais via CLI.

---
*Relatório gerado automaticamente via Claude Code.*

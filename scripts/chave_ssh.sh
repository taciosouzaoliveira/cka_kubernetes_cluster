#!/usr/bin/env bash
# Descobre os caminhos da chave SSH que o Terraform vai usar, na mesma ordem
# de precedência dele: default em variables.tf < TF_VAR_* < terraform.tfvars.
# Uso: source scripts/chave_ssh.sh  ->  define SSH_PUB_KEY e SSH_PRIV_KEY

_TF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../terraform" && pwd)"

# Lê o valor de uma variável num arquivo .tf/.tfvars (formato: nome = "valor")
_ler_var() {
  local arquivo="$1" nome="$2"
  [ -f "$arquivo" ] || return 0
  if [ "${arquivo##*.}" = "tf" ]; then
    # Em variables.tf o valor está no "default" dentro do bloco da variável
    awk -v n="$nome" '
      $0 ~ "variable \"" n "\"" { dentro = 1 }
      dentro && /default/ { sub(/.*default *= *"/, ""); sub(/".*/, ""); print; exit }
      dentro && /^}/ { dentro = 0 }
    ' "$arquivo"
  else
    sed -n "s/^[[:space:]]*${nome}[[:space:]]*=[[:space:]]*\"\(.*\)\".*/\1/p" "$arquivo" | tail -1
  fi
}

_resolver() {
  local nome="$1" valor env_var="TF_VAR_$1"
  valor="$(_ler_var "${_TF_DIR}/variables.tf" "$nome")"
  [ -n "${!env_var:-}" ] && valor="${!env_var}"
  local tfvars
  tfvars="$(_ler_var "${_TF_DIR}/terraform.tfvars" "$nome")"
  [ -n "$tfvars" ] && valor="$tfvars"
  # Expande ~ como o pathexpand() do Terraform
  echo "${valor/#\~/$HOME}"
}

SSH_PUB_KEY="$(_resolver ssh_public_key_path)"
SSH_PRIV_KEY="$(_resolver ssh_private_key_path)"
export SSH_PUB_KEY SSH_PRIV_KEY
